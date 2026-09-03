/// 网关拒掉本地签发的 token（密钥/签发者与服务端不一致、过期）时，核心报的是
/// `错误 [AUTHENTICATION_FAILED] connect failed primary=… TOKEN_REJECTED: …`——
/// 一长串传输层描述。登录页只该告诉用户「去核对签名密钥」。与 web 端 kit 的
/// isTokenRejectedError 同判据。
final RegExp _tokenRejected = RegExp(r'AUTHENTICATION_FAILED|TOKEN_REJECTED');

const String tokenRejectedLoginMessage =
    '接入 Token 被服务端拒绝：签名密钥或签发者与服务端不一致，或 Token 已过期。请核对「签名密钥」后重试。';

bool isTokenRejectedLoginError(Object error) =>
    _tokenRejected.hasMatch(error.toString());

String friendlyLoginError(Object error) =>
    isTokenRejectedLoginError(error) ? tokenRejectedLoginMessage : error.toString();
