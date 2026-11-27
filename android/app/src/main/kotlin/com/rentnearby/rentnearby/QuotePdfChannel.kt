package com.rentnearby.rentnearby

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.app.ActivityManager
import android.app.DownloadManager
import android.content.ActivityNotFoundException
import android.content.ComponentCallbacks2
import android.content.ContentUris
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import android.graphics.pdf.PdfDocument
import android.graphics.pdf.PdfRenderer
import android.net.Uri
import android.os.Build
import android.os.CancellationSignal
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.print.PrintAttributes
import android.print.QuotePdfPrinter
import android.provider.MediaStore
import android.util.Base64
import android.view.View
import android.view.ViewGroup
import android.webkit.RenderProcessGoneDetail
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.FrameLayout
import io.flutter.FlutterInjector
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import org.json.JSONTokener
import java.io.ByteArrayInputStream
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.nio.ByteBuffer
import java.util.concurrent.Executors

// Phone-side quotation PDFs (ARCHITECTURE 8): one offscreen WebView, our bundled A4 templates, silent print (E1)
// with an image-PDF fallback (E2). Every WebView call runs on the main thread, one at a time.
class QuotePdfChannel private constructor(private val activity: Activity, messenger: BinaryMessenger) :
    MethodChannel.MethodCallHandler, ComponentCallbacks2 {

    companion object {
        const val NAME = "bakhli/quote_pdf"
        private const val ORIGIN = "https://quote.invalid/"
        private const val HOST = "quote.invalid"
        private const val PAGE_W = 794
        private const val PAGE_H = 1122
        private const val PDF_W = 595
        private const val PDF_H = 842
        private const val MAX_JSON = 256 * 1024
        private const val MAX_IMAGE = 200 * 1024
        private const val MAX_QUEUE = 4
        private const val JS_TIMEOUT_MS = 8000L
        private const val RASTER_SCALE = 2.5f
        private val TEMPLATES = setOf("classic", "band", "modern")
        private val FONTS = setOf(
            "Roboto-Regular", "Roboto-Medium", "Roboto-Bold",
            "Poppins-Regular", "Poppins-Medium", "Poppins-SemiBold", "Poppins-Bold",
            "WorkSans-Regular", "WorkSans-Medium", "WorkSans-SemiBold", "WorkSans-Bold",
        )
        private val USER_ID = Regex("^[A-Za-z0-9-]{1,64}$")
        private val BAD_NAME = Regex("[\\\\/:*?\"<>|\\u0000-\\u001F\\u007F\\u200B-\\u200F\\u202A-\\u202E\\u2066-\\u2069\\uFEFF]")

        fun register(activity: Activity, messenger: BinaryMessenger): QuotePdfChannel = QuotePdfChannel(activity, messenger)
    }

    private class Fail(val code: String, message: String = code) : Exception(message)

    private data class Layout(val ok: Boolean, val pages: Int, val fit: Int, val reason: String?)

    private val channel = MethodChannel(messenger, NAME)
    private val main = Handler(Looper.getMainLooper())
    private val io = Executors.newSingleThreadExecutor()
    private val queue = ArrayDeque<() -> Unit>()
    private var running = false
    private var webView: WebView? = null
    private var holder: FrameLayout? = null
    private var template: String? = null
    private var pageReady = false
    private var onReady: (() -> Unit)? = null
    private var onGone: ((Fail) -> Unit)? = null
    private val bytesCache = HashMap<String, ByteArray>()
    private var imgUser: String? = null
    private var imgVersion = 0
    private var seq = 0

    init {
        channel.setMethodCallHandler(this)
        activity.registerComponentCallbacks(this)
    }

    // ---------- entry ----------

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "storageDir" -> result.success(mapOf("path" to root().absolutePath))
                "putImage" -> putImage(call, result)
                "clearUser" -> clearUser(call, result)
                "warmUp" -> enqueue(result) { done -> warmUp(call.argument<String>("template"), done) }
                "layout" -> enqueue(result) { done -> layoutCall(call, done) }
                "preview" -> enqueue(result) { done -> previewCall(call, done) }
                "render" -> enqueue(result) { done -> renderCall(call, done) }
                "open" -> open(call.argument<String>("uri"), result)
                "delete" -> delete(call.argument<String>("uri"), result)
                "dispose" -> {
                    if (!running) destroyWebView()
                    bytesCache.clear()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (e: Fail) {
            result.error(e.code, e.message, null)
        } catch (e: Exception) {
            result.error("RenderFailed", e.javaClass.simpleName, null)
        }
    }

    private fun enqueue(result: MethodChannel.Result, job: ((Any?, Fail?) -> Unit) -> Unit) {
        if (queue.size >= MAX_QUEUE) {
            result.error("Busy", "busy", null)
            return
        }
        queue.addLast {
            var answered = false
            val done: (Any?, Fail?) -> Unit = { value, fail ->
                if (!answered) {
                    answered = true
                    onGone = null
                    if (fail != null) result.error(fail.code, fail.message, null) else result.success(value)
                    running = false
                    main.post { next() }
                }
            }
            onGone = { f -> done(null, f) }
            try {
                job(done)
            } catch (e: Fail) {
                done(null, e)
            } catch (e: Exception) {
                done(null, Fail("RenderFailed", e.javaClass.simpleName))
            }
        }
        next()
    }

    // Async WebView callbacks must never throw into the framework: a failure ends the running call.
    private fun guard(block: () -> Unit) {
        try {
            block()
        } catch (e: Fail) {
            onGone?.invoke(e)
        } catch (e: Exception) {
            onGone?.invoke(Fail("RenderFailed", e.javaClass.simpleName))
        }
    }

    private fun next() {
        if (running) return
        val job = queue.removeFirstOrNull() ?: return
        running = true
        job()
    }

    // ---------- files ----------

    private fun root(): File = File(activity.filesDir, "quote").apply { mkdirs() }

    private fun userDir(userId: String): File {
        if (!USER_ID.matches(userId)) throw Fail("RenderFailed", "user")
        return File(root(), userId)
    }

    private fun putImage(call: MethodCall, result: MethodChannel.Result) {
        val userId = call.argument<String>("userId") ?: throw Fail("RenderFailed", "user")
        val kind = call.argument<String>("kind")
        val version = call.argument<Int>("version") ?: -1
        val bytes = call.argument<ByteArray>("bytes") ?: throw Fail("RenderFailed", "bytes")
        if (kind != "logo" && kind != "signature") throw Fail("RenderFailed", "kind")
        if (version < 0 || bytes.size > MAX_IMAGE || bytes.size < 3 ||
            bytes[0] != 0xFF.toByte() || bytes[1] != 0xD8.toByte() || bytes[2] != 0xFF.toByte()) throw Fail("RenderFailed", "image")
        val dir = userDir(userId)
        io.execute {
            try {
                dir.mkdirs()
                val target = File(dir, "${kind}_$version.jpg")
                val tmp = File(dir, "${kind}_$version.jpg.tmp")
                FileOutputStream(tmp).use { it.write(bytes) }
                if (!tmp.renameTo(target)) throw Fail("NoSpace")
                dir.listFiles()?.forEach { f ->
                    if (f.name.startsWith("${kind}_") && f.name.endsWith(".jpg") && f.name != target.name) f.delete()
                }
                main.post { result.success(null) }
            } catch (e: Exception) {
                main.post { result.error(if (e is Fail) e.code else "NoSpace", e.message, null) }
            }
        }
    }

    private fun clearUser(call: MethodCall, result: MethodChannel.Result) {
        val dir = userDir(call.argument<String>("userId") ?: throw Fail("RenderFailed", "user"))
        if (!running) destroyWebView()
        io.execute {
            dir.deleteRecursively()
            File(activity.cacheDir, "quote").deleteRecursively()
            main.post { result.success(null) }
        }
    }

    private fun imageFile(name: String): File? {
        val user = imgUser ?: return null
        if (imgVersion <= 0 || !USER_ID.matches(user)) return null
        val f = File(File(root(), user), "${name}_$imgVersion.jpg")
        return if (f.isFile && f.length() in 3..MAX_IMAGE.toLong()) f else null
    }

    // ---------- WebView ----------

    private fun lowRam(): Boolean {
        val am = activity.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager ?: return false
        val info = ActivityManager.MemoryInfo()
        am.getMemoryInfo(info)
        return am.isLowRamDevice || info.lowMemory
    }

    @SuppressLint("SetJavaScriptEnabled")
    @Suppress("DEPRECATION")
    private fun ensureWebView(): WebView {
        webView?.let { return it }
        val view = try {
            WebView(activity)
        } catch (e: Exception) {
            throw Fail("Unsupported", "webview")
        }
        WebView.setWebContentsDebuggingEnabled((activity.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0)
        view.settings.apply {
            javaScriptEnabled = true
            blockNetworkLoads = true
            allowFileAccess = false
            allowContentAccess = false
            allowFileAccessFromFileURLs = false
            allowUniversalAccessFromFileURLs = false
            mixedContentMode = WebSettings.MIXED_CONTENT_NEVER_ALLOW
            javaScriptCanOpenWindowsAutomatically = false
            setSupportMultipleWindows(false)
            setGeolocationEnabled(false)
            domStorageEnabled = false
            databaseEnabled = false
            useWideViewPort = true
            loadWithOverviewMode = true
            setSupportZoom(false)
            builtInZoomControls = false
            textZoom = 100
            cacheMode = WebSettings.LOAD_NO_CACHE
        }
        view.isVerticalScrollBarEnabled = false
        view.isHorizontalScrollBarEnabled = false
        view.setBackgroundColor(Color.WHITE)
        view.importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO_HIDE_DESCENDANTS
        view.webViewClient = object : WebViewClient() {
            override fun shouldOverrideUrlLoading(v: WebView, request: WebResourceRequest): Boolean = true

            override fun shouldInterceptRequest(v: WebView, request: WebResourceRequest): WebResourceResponse = intercept(request.url)

            override fun onPageFinished(v: WebView, url: String?) {
                if (v !== webView) return
                pageReady = true
                val r = onReady
                onReady = null
                if (r != null) guard(r)
            }

            override fun onRenderProcessGone(v: WebView, detail: RenderProcessGoneDetail?): Boolean {
                if (v === webView) {
                    destroyWebView()
                    onGone?.invoke(Fail("RenderFailed", "renderer gone"))
                } else {
                    (v.parent as? ViewGroup)?.removeView(v)
                    v.destroy()
                }
                return true
            }
        }
        // Attached far off-screen so the renderer draws it like a real view; never visible, never focusable.
        val box = FrameLayout(activity)
        box.translationX = -100_000f
        box.isClickable = false
        box.isFocusable = false
        box.importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO_HIDE_DESCENDANTS
        box.addView(view, FrameLayout.LayoutParams(PAGE_W, PAGE_H))
        val content = activity.findViewById<ViewGroup>(android.R.id.content)
        content?.addView(box, 0, FrameLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT))
        holder = box
        webView = view
        template = null
        pageReady = false
        return view
    }

    private fun destroyWebView() {
        val view = webView ?: return
        webView = null
        template = null
        pageReady = false
        onReady = null
        holder?.let { (it.parent as? ViewGroup)?.removeView(it) }
        holder = null
        try {
            view.stopLoading()
            view.destroy()
        } catch (_: Exception) {
        }
    }

    private fun asset(path: String): ByteArray {
        bytesCache[path]?.let { return it }
        val key = FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(path)
        val bytes = activity.assets.open(key).use { it.readBytes() }
        if (!path.endsWith(".html")) bytesCache[path] = bytes
        return bytes
    }

    private fun empty404() = WebResourceResponse("text/plain", "utf-8", 404, "Not Found", emptyMap(), ByteArrayInputStream(ByteArray(0)))

    private fun ok(mime: String, bytes: ByteArray) =
        WebResourceResponse(mime, if (mime.startsWith("text") || mime.contains("javascript")) "utf-8" else null, 200, "OK", mapOf("Cache-Control" to "no-store"), ByteArrayInputStream(bytes))

    // Fixed whitelist (ARCHITECTURE 8.4.4); anything else is an empty 404.
    private fun intercept(url: Uri?): WebResourceResponse {
        if (url == null || url.scheme != "https" || url.host != HOST) return empty404()
        val path = url.path ?: return empty404()
        return try {
            when {
                path == "/quote.css" -> ok("text/css", asset("assets/quote_templates/quote.css"))
                path == "/quote.js" -> ok("application/javascript", asset("assets/quote_templates/quote.js"))
                path.startsWith("/fonts/") && path.endsWith(".ttf") -> {
                    val name = path.removePrefix("/fonts/").removeSuffix(".ttf")
                    if (name in FONTS) ok("font/ttf", asset("assets/fonts/$name.ttf")) else empty404()
                }
                path == "/img/logo.jpg" -> imageFile("logo")?.let { ok("image/jpeg", it.readBytes()) } ?: empty404()
                path == "/img/signature.jpg" -> imageFile("signature")?.let { ok("image/jpeg", it.readBytes()) } ?: empty404()
                else -> empty404()
            }
        } catch (e: Exception) {
            empty404()
        }
    }

    private fun loadTemplate(name: String, then: () -> Unit) {
        if (name !in TEMPLATES) throw Fail("RenderFailed", "template")
        val view = ensureWebView()
        if (template == name && pageReady) {
            then()
            return
        }
        template = name
        pageReady = false
        onReady = then
        val html = String(asset("assets/quote_templates/$name.html"), Charsets.UTF_8)
        view.loadDataWithBaseURL(ORIGIN, html, "text/html", "utf-8", null)
    }

    private fun warmUp(name: String?, done: (Any?, Fail?) -> Unit) {
        if (lowRam() || name == null) {
            done(null, null)
            return
        }
        loadTemplate(name) { done(null, null) }
    }

    // ---------- fill + fit ----------

    private fun parseDoc(json: String) {
        val o = JSONObject(json)
        val owner = o.optString("owner", "")
        imgUser = if (USER_ID.matches(owner)) owner else null
        imgVersion = o.optInt("assetsVersion", 0)
    }

    private fun fill(call: MethodCall, minFit: Int, then: (Layout) -> Unit) {
        val name = call.argument<String>("template") ?: throw Fail("RenderFailed", "template")
        val json = call.argument<String>("json") ?: throw Fail("RenderFailed", "json")
        val utf8 = json.toByteArray(Charsets.UTF_8)
        if (utf8.size > MAX_JSON) throw Fail("TooLong")
        parseDoc(json)
        val b64 = Base64.encodeToString(utf8, Base64.NO_WRAP)
        loadTemplate(name) {
            val view = webView ?: throw Fail("RenderFailed", "gone")
            val id = ++seq
            view.evaluateJavascript("window.__quote&&__quote.render('$b64',$minFit,$id)", null)
            poll(view, id, System.currentTimeMillis() + JS_TIMEOUT_MS, then)
        }
    }

    private fun poll(view: WebView, id: Int, until: Long, then: (Layout) -> Unit) {
        if (view !== webView) return
        view.evaluateJavascript("window.__quoteState||''") { raw ->
            if (view !== webView) return@evaluateJavascript
            val state = try {
                val s = JSONTokener(raw ?: "").nextValue() as? String
                if (s.isNullOrEmpty()) null else JSONObject(s)
            } catch (_: Exception) {
                null
            }
            if (state != null && state.optInt("id") == id) {
                val layout = Layout(state.optBoolean("ok"), state.optInt("pages"), state.optInt("fit"), state.optString("reason").ifEmpty { null })
                view.postVisualStateCallback(id.toLong(), object : WebView.VisualStateCallback() {
                    override fun onComplete(requestId: Long) {
                        if (view === webView) guard { then(layout) }
                    }
                })
            } else if (System.currentTimeMillis() > until) {
                onGone?.invoke(Fail("RenderFailed", "timeout"))
            } else {
                main.postDelayed({ poll(view, id, until, then) }, 16)
            }
        }
    }

    private fun layoutMap(l: Layout) = mapOf("ok" to l.ok, "pages" to l.pages, "fit" to l.fit, "reason" to l.reason)

    private fun layoutCall(call: MethodCall, done: (Any?, Fail?) -> Unit) = fill(call, 0) { l -> done(layoutMap(l), null) }

    // ---------- preview ----------

    private fun resize(w: Int, h: Int, then: () -> Unit) {
        val view = webView ?: throw Fail("RenderFailed", "gone")
        view.layoutParams = FrameLayout.LayoutParams(w, h)
        view.requestLayout()
        val id = ++seq
        view.post {
            if (view !== webView) return@post
            view.postVisualStateCallback(id.toLong(), object : WebView.VisualStateCallback() {
                override fun onComplete(requestId: Long) {
                    if (view === webView) guard(then)
                }
            })
        }
    }

    private fun watermark(bitmap: Bitmap, label: String) {
        val c = Canvas(bitmap)
        val p = Paint(Paint.ANTI_ALIAS_FLAG)
        p.color = Color.argb(26, 90, 90, 90)
        p.textSize = bitmap.width / 9f
        p.typeface = Typeface.DEFAULT_BOLD
        val step = bitmap.width / 2f
        c.save()
        c.rotate(-30f, bitmap.width / 2f, bitmap.height / 2f)
        var y = -bitmap.height.toFloat()
        while (y < bitmap.height * 2) {
            var x = -bitmap.width.toFloat()
            while (x < bitmap.width * 2) {
                c.drawText(label, x, y, p)
                x += step * 1.6f
            }
            y += step
        }
        c.restore()
    }

    private fun previewCall(call: MethodCall, done: (Any?, Fail?) -> Unit) {
        val widthPx = (call.argument<Int>("widthPx") ?: 1080).coerceIn(200, 1080)
        val mark = call.argument<Boolean>("watermark") == true
        fill(call, 0) { l ->
            if (!l.ok && l.pages == 0) {
                done(null, Fail(l.reason ?: "RenderFailed"))
                return@fill
            }
            val pages = l.pages.coerceIn(1, 2)
            val pageH = Math.round(widthPx * PAGE_H.toFloat() / PAGE_W)
            resize(widthPx, pageH * pages) {
                val view = webView ?: return@resize done(null, Fail("RenderFailed", "gone"))
                val bitmaps = ArrayList<Bitmap>()
                try {
                    for (i in 0 until pages) {
                        val b = Bitmap.createBitmap(widthPx, pageH, Bitmap.Config.ARGB_8888)
                        val c = Canvas(b)
                        c.drawColor(Color.WHITE)
                        c.translate(0f, -(i * pageH).toFloat())
                        view.draw(c)
                        if (mark) watermark(b, "PREVIEW")
                        bitmaps.add(b)
                    }
                } catch (e: OutOfMemoryError) {
                    bitmaps.forEach { it.recycle() }
                    done(null, Fail("RenderFailed", "memory"))
                    return@resize
                }
                io.execute {
                    val out = bitmaps.map { b ->
                        val buf = ByteBuffer.allocate(b.byteCount)
                        b.copyPixelsToBuffer(buf)
                        val m = mapOf("width" to b.width, "height" to b.height, "rgba" to buf.array())
                        b.recycle()
                        m
                    }
                    main.post { done(mapOf("pages" to out, "fit" to l.fit), null) }
                }
            }
        }
    }

    // ---------- render ----------

    private fun safeName(raw: String?): String {
        var n = (raw ?: "").replace(BAD_NAME, "").trim().trimStart('.')
        if (n.lowercase().endsWith(".pdf")) n = n.dropLast(4)
        if (n.isEmpty()) n = "Quotation"
        if (n.length > 76) n = n.take(76)
        return "$n.pdf"
    }

    private class Target(val uri: Uri?, val file: File?, val pfd: ParcelFileDescriptor)

    private fun openTarget(name: String): Target {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, name)
                put(MediaStore.MediaColumns.MIME_TYPE, "application/pdf")
                put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
            val uri = activity.contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values) ?: throw Fail("NoSpace")
            val pfd = activity.contentResolver.openFileDescriptor(uri, "rw") ?: run {
                activity.contentResolver.delete(uri, null, null)
                throw Fail("NoSpace")
            }
            return Target(uri, null, pfd)
        }
        val dir = File(activity.cacheDir, "quote").apply { mkdirs() }
        val f = File(dir, "${System.currentTimeMillis()}.pdf")
        val pfd = ParcelFileDescriptor.open(f, ParcelFileDescriptor.MODE_READ_WRITE or ParcelFileDescriptor.MODE_CREATE or ParcelFileDescriptor.MODE_TRUNCATE)
        return Target(null, f, pfd)
    }

    private fun dropTarget(t: Target) {
        closeQuietly(t.pfd)
        t.uri?.let {
            try {
                activity.contentResolver.delete(it, null, null)
            } catch (_: Exception) {
            }
        }
        t.file?.delete()
    }

    // Opens the written file and checks page count and A4 size; a stray blank page is a failure.
    private fun verify(t: Target, pages: Int): Boolean {
        return try {
            val read = (if (t.uri != null) activity.contentResolver.openFileDescriptor(t.uri, "r") else ParcelFileDescriptor.open(t.file, ParcelFileDescriptor.MODE_READ_ONLY))
                ?: return false
            val renderer = PdfRenderer(read)
            try {
                if (renderer.pageCount != pages) return false
                for (i in 0 until renderer.pageCount) {
                    val page = renderer.openPage(i)
                    val a4 = Math.abs(page.width - PDF_W) <= 2 && Math.abs(page.height - PDF_H) <= 2
                    page.close()
                    if (!a4) return false
                }
                true
            } finally {
                renderer.close()
                read.close()
            }
        } catch (e: Exception) {
            false
        }
    }

    private fun printE1(name: String, t: Target, then: (Boolean) -> Unit) {
        val view = webView ?: return then(false)
        val attrs = PrintAttributes.Builder()
            .setMediaSize(PrintAttributes.MediaSize.ISO_A4)
            .setResolution(PrintAttributes.Resolution("quote", "quote", 300, 300))
            .setMinMargins(PrintAttributes.Margins.NO_MARGINS)
            .setColorMode(PrintAttributes.COLOR_MODE_COLOR)
            .build()
        val adapter = view.createPrintDocumentAdapter(name)
        QuotePdfPrinter(attrs).print(adapter, t.pfd, CancellationSignal(), object : QuotePdfPrinter.Callback {
            override fun onDone() {
                main.post { guard { then(true) } }
            }

            override fun onFailed(reason: String) {
                main.post { guard { then(false) } }
            }
        })
    }

    // E2: the same WebView drawn page by page into one reused bitmap at 2.5x (one retry at 2x on low memory).
    private fun printE2(pages: Int, t: Target, scale: Float, then: (Boolean) -> Unit) {
        val w = Math.round(PAGE_W * scale)
        val h = Math.round(PAGE_H * scale)
        resize(w, h * pages) {
            val view = webView ?: return@resize then(false)
            var bitmap: Bitmap? = null
            val doc = PdfDocument()
            try {
                bitmap = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
                val bc = Canvas(bitmap)
                val paint = Paint(Paint.FILTER_BITMAP_FLAG)
                for (i in 0 until pages) {
                    bc.save()
                    bc.drawColor(Color.WHITE)
                    bc.translate(0f, -(i * h).toFloat())
                    view.draw(bc)
                    bc.restore()
                    val page = doc.startPage(PdfDocument.PageInfo.Builder(PDF_W, PDF_H, i + 1).create())
                    page.canvas.save()
                    page.canvas.scale(PDF_W.toFloat() / w, PDF_H.toFloat() / h)
                    page.canvas.drawBitmap(bitmap, 0f, 0f, paint)
                    page.canvas.restore()
                    doc.finishPage(page)
                }
                val bmp = bitmap
                io.execute {
                    val ok = try {
                        FileOutputStream(t.pfd.fileDescriptor).use { doc.writeTo(it) }
                        true
                    } catch (e: Exception) {
                        false
                    } finally {
                        doc.close()
                        bmp.recycle()
                    }
                    main.post { guard { then(ok) } }
                }
            } catch (e: OutOfMemoryError) {
                doc.close()
                bitmap?.recycle()
                if (scale > 2f) printE2(pages, t, 2f, then) else then(false)
            }
        }
    }

    private fun closeQuietly(pfd: ParcelFileDescriptor) {
        try {
            pfd.close()
        } catch (_: Exception) {
        }
    }

    private fun publish(t: Target, name: String): Pair<String, Long> {
        if (t.uri != null) {
            closeQuietly(t.pfd)
            val size = activity.contentResolver.openFileDescriptor(t.uri, "r")?.use { it.statSize } ?: 0L
            activity.contentResolver.update(t.uri, ContentValues().apply { put(MediaStore.MediaColumns.IS_PENDING, 0) }, null, null)
            return Pair(t.uri.toString(), size)
        }
        closeQuietly(t.pfd)
        val src = t.file ?: throw Fail("RenderFailed", "file")
        try {
            @Suppress("DEPRECATION")
            val dir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS).apply { mkdirs() }
            var out = File(dir, name)
            var n = 1
            while (out.exists()) {
                out = File(dir, name.removeSuffix(".pdf") + "_$n.pdf")
                n++
            }
            FileInputStream(src).use { input -> FileOutputStream(out).use { input.copyTo(it) } }
            val dm = activity.getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
            @Suppress("DEPRECATION")
            val id = dm.addCompletedDownload(out.name, out.name, true, "application/pdf", out.absolutePath, out.length(), false)
            val uri = dm.getUriForDownloadedFile(id) ?: throw Fail("RenderFailed", "uri")
            return Pair(uri.toString(), out.length())
        } catch (e: SecurityException) {
            throw Fail("StorageDenied")
        } finally {
            src.delete()
        }
    }

    private fun renderCall(call: MethodCall, done: (Any?, Fail?) -> Unit) {
        val name = safeName(call.argument<String>("fileName"))
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q &&
            activity.checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) {
            throw Fail("StorageDenied")
        }
        fun attempt(minFit: Int, retried: Boolean) {
            fill(call, minFit) { l ->
                if (!l.ok) {
                    done(null, Fail(l.reason ?: "RenderFailed"))
                    return@fill
                }
                val t = try {
                    openTarget(name)
                } catch (e: Fail) {
                    done(null, e)
                    return@fill
                } catch (e: Exception) {
                    done(null, Fail("NoSpace"))
                    return@fill
                }
                printE1(name, t) { printed ->
                    if (printed && verify(t, l.pages)) {
                        finishRender(t, name, l, "print", done)
                    } else if (!retried && l.fit < 2) {
                        dropTarget(t)
                        attempt(l.fit + 1, true)
                    } else {
                        dropTarget(t)
                        val t2 = try {
                            openTarget(name)
                        } catch (e: Exception) {
                            done(null, if (e is Fail) e else Fail("NoSpace"))
                            return@printE1
                        }
                        printE2(l.pages, t2, RASTER_SCALE) { ok ->
                            if (ok && verify(t2, l.pages)) finishRender(t2, name, l, "raster", done) else {
                                dropTarget(t2)
                                done(null, Fail("RenderFailed", "verify"))
                            }
                        }
                    }
                }
            }
        }
        attempt(0, false)
    }

    private fun finishRender(t: Target, name: String, l: Layout, engine: String, done: (Any?, Fail?) -> Unit) {
        try {
            val (uri, size) = publish(t, name)
            resize(PAGE_W, PAGE_H) {}
            done(mapOf("uri" to uri, "displayName" to name, "pages" to l.pages, "engine" to engine, "bytes" to size), null)
        } catch (e: Fail) {
            dropTarget(t)
            done(null, e)
        } catch (e: Exception) {
            dropTarget(t)
            done(null, Fail("NoSpace"))
        }
    }

    // ---------- open / delete ----------

    private fun parseUri(raw: String?): Uri {
        val uri = Uri.parse(raw ?: throw Fail("RenderFailed", "uri"))
        if (uri.scheme != "content") throw Fail("RenderFailed", "uri")
        return uri
    }

    private fun open(raw: String?, result: MethodChannel.Result) {
        val uri = parseUri(raw)
        val exists = try {
            activity.contentResolver.openFileDescriptor(uri, "r")?.use { true } ?: false
        } catch (e: Exception) {
            false
        }
        if (!exists) {
            result.success(mapOf("missing" to true))
            return
        }
        val intent = Intent(Intent.ACTION_VIEW).setDataAndType(uri, "application/pdf")
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            activity.startActivity(intent)
            result.success(mapOf("opened" to true))
        } catch (e: ActivityNotFoundException) {
            result.success(mapOf("noApp" to true))
        }
    }

    private fun delete(raw: String?, result: MethodChannel.Result) {
        val uri = try {
            parseUri(raw)
        } catch (e: Fail) {
            result.success(null)
            return
        }
        io.execute {
            try {
                if (uri.authority == "downloads") {
                    val dm = activity.getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
                    dm.remove(ContentUris.parseId(uri))
                } else {
                    activity.contentResolver.delete(uri, null, null)
                }
            } catch (_: Exception) {
            }
            main.post { result.success(null) }
        }
    }

    // ---------- memory ----------

    @Suppress("DEPRECATION")
    override fun onTrimMemory(level: Int) {
        if (running) return
        if (level >= ComponentCallbacks2.TRIM_MEMORY_RUNNING_LOW || level == ComponentCallbacks2.TRIM_MEMORY_UI_HIDDEN) {
            destroyWebView()
            bytesCache.clear()
        }
    }

    override fun onConfigurationChanged(newConfig: Configuration) {}

    @Deprecated("Deprecated in Java")
    override fun onLowMemory() {
        if (!running) destroyWebView()
    }

    fun dispose() {
        activity.unregisterComponentCallbacks(this)
        channel.setMethodCallHandler(null)
        destroyWebView()
        io.shutdown()
    }
}
