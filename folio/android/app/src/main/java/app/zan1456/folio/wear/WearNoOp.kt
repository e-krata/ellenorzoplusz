package hu.ekrata.ellenorzoplusz.wear

import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.nio.ByteBuffer

private object NoOpBinaryMessenger : BinaryMessenger {
    override fun send(channel: String, message: ByteBuffer?) {}
    override fun send(channel: String, message: ByteBuffer?, callback: BinaryMessenger.BinaryReply?) {}
    override fun setMessageHandler(channel: String, handler: BinaryMessenger.BinaryMessageHandler?) {}
}

internal object NoOpMethodChannel : MethodChannel(NoOpBinaryMessenger, "noop") {
    override fun invokeMethod(method: String, arguments: Any?) {}
    override fun invokeMethod(method: String, arguments: Any?, callback: MethodChannel.Result?) {}
}
