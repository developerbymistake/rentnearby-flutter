package android.print

import android.os.CancellationSignal
import android.os.ParcelFileDescriptor
import androidx.annotation.Keep

// Runs a WebView print adapter silently into a file. Lives in android.print because the two result
// callbacks have package-private constructors (same mechanism as the printing plugin's PdfConvert).
@Keep
class QuotePdfPrinter(private val attributes: PrintAttributes) {

    @Keep
    interface Callback {
        fun onDone()
        fun onFailed(reason: String)
    }

    fun print(adapter: PrintDocumentAdapter, out: ParcelFileDescriptor, cancel: CancellationSignal, callback: Callback) {
        var finished = false
        fun finish(ok: Boolean, reason: String) {
            if (finished) return
            finished = true
            try {
                adapter.onFinish()
            } catch (_: Exception) {
            }
            if (ok) callback.onDone() else callback.onFailed(reason)
        }
        try {
            adapter.onStart()
            adapter.onLayout(null, attributes, cancel, object : PrintDocumentAdapter.LayoutResultCallback() {
                override fun onLayoutFinished(info: PrintDocumentInfo, changed: Boolean) {
                    adapter.onWrite(arrayOf(PageRange.ALL_PAGES), out, cancel, object : PrintDocumentAdapter.WriteResultCallback() {
                        override fun onWriteFinished(pages: Array<PageRange>) = finish(true, "")
                        override fun onWriteFailed(error: CharSequence?) = finish(false, error?.toString() ?: "write failed")
                        override fun onWriteCancelled() = finish(false, "write cancelled")
                    })
                }

                override fun onLayoutFailed(error: CharSequence?) = finish(false, error?.toString() ?: "layout failed")
                override fun onLayoutCancelled() = finish(false, "layout cancelled")
            }, null)
        } catch (e: Exception) {
            finish(false, e.javaClass.simpleName)
        }
    }
}
