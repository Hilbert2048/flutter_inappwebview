import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:flutter_inappwebview_platform_interface/flutter_inappwebview_platform_interface.dart';

import 'in_app_webview/headless_in_app_webview.dart';
import 'platform_util.dart';

/// Object specifying creation parameters for creating a [AndroidCookieManager].
///
/// When adding additional fields make sure they can be null or have a default
/// value to avoid breaking changes. See [PlatformCookieManagerCreationParams] for
/// more information.
@immutable
class AndroidCookieManagerCreationParams
    extends PlatformCookieManagerCreationParams {
  /// Creates a new [AndroidCookieManagerCreationParams] instance.
  const AndroidCookieManagerCreationParams(
    // This parameter prevents breaking changes later.
    // ignore: avoid_unused_constructor_parameters
    PlatformCookieManagerCreationParams params,
  ) : super();

  /// Creates a [AndroidCookieManagerCreationParams] instance based on [PlatformCookieManagerCreationParams].
  factory AndroidCookieManagerCreationParams.fromPlatformCookieManagerCreationParams(
      PlatformCookieManagerCreationParams params) {
    return AndroidCookieManagerCreationParams(params);
  }
}

///Class that implements a singleton object (shared instance) which manages the cookies used by WebView instances.
///On Android, it is implemented using [CookieManager](https://developer.android.com/reference/android/webkit/CookieManager).
///On iOS, it is implemented using [WKHTTPCookieStore](https://developer.apple.com/documentation/webkit/wkhttpcookiestore).
///
///**NOTE for iOS below 11.0 and Web platform (LIMITED SUPPORT!)**: in this case, almost all of the methods ([AndroidCookieManager.deleteAllCookies] and [AndroidCookieManager.getAllCookies] are not supported!)
///has been implemented using JavaScript because there is no other way to work with them on iOS below 11.0.
///See https://developer.mozilla.org/en-US/docs/Web/HTTP/Cookies#restrict_access_to_cookies for JavaScript restrictions.
///
///**Supported Platforms/Implementations**:
///- Android native WebView
///- iOS
///- MacOS
///- Web
class AndroidCookieManager extends PlatformCookieManager
    with ChannelController {
  /// Creates a new [AndroidCookieManager].
  AndroidCookieManager(PlatformCookieManagerCreationParams params)
      : super.implementation(
          params is AndroidCookieManagerCreationParams
              ? params
              : AndroidCookieManagerCreationParams
                  .fromPlatformCookieManagerCreationParams(params),
        ) {
    channel = const MethodChannel(
        'com.pichillilorenzo/flutter_inappwebview_cookiemanager');
    handler = handleMethod;
    initMethodCallHandler();
  }

  static AndroidCookieManager? _instance;

  ///Gets the [AndroidCookieManager] shared instance.
  static AndroidCookieManager instance() {
    return (_instance != null) ? _instance! : _init();
  }

  static AndroidCookieManager _init() {
    _instance = AndroidCookieManager(AndroidCookieManagerCreationParams(
        const PlatformCookieManagerCreationParams()));
    return _instance!;
  }

  Future<dynamic> _handleMethod(MethodCall call) async {}

  ///Sets a cookie for the given [url]. Any existing cookie with the same [host], [path] and [name] will be replaced with the new cookie.
  ///The cookie being set will be ignored if it is expired.
  ///
  ///The default value of [path] is `"/"`.
  ///
  ///[webViewController] could be used if you need to set a session-only cookie using JavaScript (so [isHttpOnly] cannot be set, see: https://developer.mozilla.org/en-US/docs/Web/HTTP/Cookies#restrict_access_to_cookies)
  ///on the current URL of the [WebView] managed by that controller when you need to target iOS below 11, MacOS below 10.13 and Web platform. In this case the [url] parameter is ignored.
  ///
  ///The return value indicates whether the cookie was set successfully.
  ///Note that it will return always `true` for Web platform, iOS below 11.0 and MacOS below 10.13.
  ///
  ///**NOTE for iOS below 11.0 and MacOS below 10.13**: If [webViewController] is `null` or JavaScript is disabled for it, it will try to use a [AndroidHeadlessInAppWebView]
  ///to set the cookie (session-only cookie won't work! In that case, you should set also [expiresDate] or [maxAge]).
  ///
  ///**NOTE for Web**: this method will have effect only if the iframe has the same origin.
  ///If [webViewController] is `null` or JavaScript is disabled for it, it will try to use a [AndroidHeadlessInAppWebView]
  ///to set the cookie (session-only cookie won't work! In that case, you should set also [expiresDate] or [maxAge]).
  ///
  ///**Supported Platforms/Implementations**:
  ///- Android native WebView ([Official API - CookieManager.setCookie](https://developer.android.com/reference/android/webkit/CookieManager#setCookie(java.lang.String,%20java.lang.String,%20android.webkit.ValueCallback%3Cjava.lang.Boolean%3E)))
  ///- iOS ([Official API - WKHTTPCookieStore.setCookie](https://developer.apple.com/documentation/webkit/wkhttpcookiestore/2882007-setcookie))
  ///- MacOS ([Official API - WKHTTPCookieStore.setCookie](https://developer.apple.com/documentation/webkit/wkhttpcookiestore/2882007-setcookie))
  ///- Web
  @override
  Future<bool> setCookie(
      {required WebUri url,
      required String name,
      required String value,
      String path = "/",
      String? domain,
      int? expiresDate,
      int? maxAge,
      bool? isSecure,
      bool? isHttpOnly,
      HTTPCookieSameSitePolicy? sameSite,
      @Deprecated("Use webViewController instead")
      PlatformInAppWebViewController? iosBelow11WebViewController,
      PlatformInAppWebViewController? webViewController}) async {
    webViewController = webViewController ?? iosBelow11WebViewController;

    assert(url.toString().isNotEmpty);
    assert(name.isNotEmpty);
    assert(value.isNotEmpty);
    assert(path.isNotEmpty);

    if (await _shouldUseJavascript()) {
      await _setCookieWithJavaScript(
          url: url,
          name: name,
          value: value,
          domain: domain,
          path: path,
          expiresDate: expiresDate,
          maxAge: maxAge,
          isSecure: isSecure,
          sameSite: sameSite,
          webViewController: webViewController);
      return true;
    }

    Map<String, dynamic> args = <String, dynamic>{};
    args.putIfAbsent('url', () => url.toString());
    args.putIfAbsent('name', () => name);
    args.putIfAbsent('value', () => value);
    args.putIfAbsent('domain', () => domain);
    args.putIfAbsent('path', () => path);
    args.putIfAbsent('expiresDate', () => expiresDate?.toString());
    args.putIfAbsent('maxAge', () => maxAge);
    args.putIfAbsent('isSecure', () => isSecure);
    args.putIfAbsent('isHttpOnly', () => isHttpOnly);
    args.putIfAbsent('sameSite', () => sameSite?.toNativeValue());

    return await channel?.invokeMethod<bool>('setCookie', args) ?? false;
  }

  Future<void> _setCookieWithJavaScript(
      {required WebUri url,
      required String name,
      required String value,
      String path = "/",
      String? domain,
      int? expiresDate,
      int? maxAge,
      bool? isSecure,
      HTTPCookieSameSitePolicy? sameSite,
      PlatformInAppWebViewController? webViewController}) async {
    var cookieValue = name + "=" + value + "; Path=" + path;

    if (domain != null) cookieValue += "; Domain=" + domain;

    if (expiresDate != null)
      cookieValue += "; Expires=" + await _getCookieExpirationDate(expiresDate);

    if (maxAge != null) cookieValue += "; Max-Age=" + maxAge.toString();

    if (isSecure != null && isSecure) cookieValue += "; Secure";

    if (sameSite != null)
      cookieValue += "; SameSite=" + sameSite.toNativeValue();

    cookieValue += ";";

    if (webViewController != null) {
      final javaScriptEnabled =
          (await webViewController.getSettings())?.javaScriptEnabled ?? false;
      if (javaScriptEnabled) {
        await webViewController.evaluateJavascript(
            source: 'document.cookie="$cookieValue"');
        return;
      }
    }

    final setCookieCompleter = Completer<void>();
    final headlessWebView =
        AndroidHeadlessInAppWebView(AndroidHeadlessInAppWebViewCreationParams(
      initialUrlRequest: URLRequest(url: url),
      onLoadStop: (controller, url) async {
        await controller.evaluateJavascript(
            source: 'document.cookie="$cookieValue"');
        setCookieCompleter.complete();
      },
    ));
    await headlessWebView.run();
    await setCookieCompleter.future;
    await headlessWebView.dispose();
  }

  ///Gets all the cookies for the given [url].
  ///
  ///[webViewController] is used for getting the cookies (also session-only cookies) using JavaScript (cookies with `isHttpOnly` enabled cannot be found, see: https://developer.mozilla.org/en-US/docs/Web/HTTP/Cookies#restrict_access_to_cookies)
  ///from the current context of the [WebView] managed by that controller when you need to target iOS below 11, MacOS below 10.13 and Web platform. JavaScript must be enabled in order to work.
  ///In this case the [url] parameter is ignored.
  ///
  ///**NOTE for iOS below 11.0 and MacOS below 10.13**: All the cookies returned this way will have all the properties to `null` except for [Cookie.name] and [Cookie.value].
  ///If [webViewController] is `null` or JavaScript is disabled for it, it will try to use a [AndroidHeadlessInAppWebView]
  ///to get the cookies (session-only cookies and cookies with `isHttpOnly` enabled won't be found!).
  ///
  ///**NOTE for Web**: this method will have effect only if the iframe has the same origin.
  ///If [webViewController] is `null` or JavaScript is disabled for it, it will try to use a [AndroidHeadlessInAppWebView]
  ///to get the cookies (session-only cookies and cookies with `isHttpOnly` enabled won't be found!).
  ///
  ///**Supported Platforms/Implementations**:
  ///- Android native WebView ([Official API - CookieManager.getCookie](https://developer.android.com/reference/android/webkit/CookieManager#getCookie(java.lang.String)))
  ///- iOS ([Official API - WKHTTPCookieStore.getAllCookies](https://developer.apple.com/documentation/webkit/wkhttpcookiestore/2882005-getallcookies))
  ///- MacOS ([Official API - WKHTTPCookieStore.getAllCookies](https://developer.apple.com/documentation/webkit/wkhttpcookiestore/2882005-getallcookies))
  ///- Web
  @override
  Future<List<Cookie>> getCookies(
      {required WebUri url,
      @Deprecated("Use webViewController instead")
      PlatformInAppWebViewController? iosBelow11WebViewController,
      PlatformInAppWebViewController? webViewController}) async {
    assert(url.toString().isNotEmpty);

    webViewController = webViewController ?? iosBelow11WebViewController;

    if (await _shouldUseJavascript()) {
      return await _getCookiesWithJavaScript(
          url: url, webViewController: webViewController);
    }

    List<Cookie> cookies = [];

    Map<String, dynamic> args = <String, dynamic>{};
    args.putIfAbsent('url', () => url.toString());
    List<dynamic> cookieListMap =
        await channel?.invokeMethod<List>('getCookies', args) ?? [];
    cookieListMap = cookieListMap.cast<Map<dynamic, dynamic>>();

    cookieListMap.forEach((cookieMap) {
      cookies.add(Cookie(
          name: cookieMap["name"],
          value: cookieMap["value"],
          expiresDate: cookieMap["expiresDate"],
          isSessionOnly: cookieMap["isSessionOnly"],
          domain: cookieMap["domain"],
          sameSite:
              HTTPCookieSameSitePolicy.fromNativeValue(cookieMap["sameSite"]),
          isSecure: cookieMap["isSecure"],
          isHttpOnly: cookieMap["isHttpOnly"],
          path: cookieMap["path"]));
    });
    return cookies;
  }

  Future<List<Cookie>> _getCookiesWithJavaScript(
      {required WebUri url,
      PlatformInAppWebViewController? webViewController}) async {
    assert(url.toString().isNotEmpty);

    List<Cookie> cookies = [];

    if (webViewController != null) {
      final javaScriptEnabled =
          (await webViewController.getSettings())?.javaScriptEnabled ?? false;
      if (javaScriptEnabled) {
        List<String> documentCookies = (await webViewController
                .evaluateJavascript(source: 'document.cookie') as String)
            .split(';')
            .map((documentCookie) => documentCookie.trim())
            .toList();
        documentCookies.forEach((documentCookie) {
          List<String> cookie = documentCookie.split('=');
          if (cookie.length > 1) {
            cookies.add(Cookie(
              name: cookie[0],
              value: cookie[1],
            ));
          }
        });
        return cookies;
      }
    }

    final pageLoaded = Completer<void>();
    final headlessWebView =
        AndroidHeadlessInAppWebView(AndroidHeadlessInAppWebViewCreationParams(
      initialUrlRequest: URLRequest(url: url),
      onLoadStop: (controller, url) async {
        pageLoaded.complete();
      },
    ));
    await headlessWebView.run();
    await pageLoaded.future;

    List<String> documentCookies = (await headlessWebView.webViewController!
            .evaluateJavascript(source: 'document.cookie') as String)
        .split(';')
        .map((documentCookie) => documentCookie.trim())
        .toList();
    documentCookies.forEach((documentCookie) {
      List<String> cookie = documentCookie.split('=');
      if (cookie.length > 1) {
        cookies.add(Cookie(
          name: cookie[0],
          value: cookie[1],
        ));
      }
    });
    await headlessWebView.dispose();
    return cookies;
  }

  ///Gets a cookie by its [name] for the given [url].
  ///
  ///[webViewController] is used for getting the cookie (also session-only cookie) using JavaScript (cookie with `isHttpOnly` enabled cannot be found, see: https://developer.mozilla.org/en-US/docs/Web/HTTP/Cookies#restrict_access_to_cookies)
  ///from the current context of the [WebView] managed by that controller when you need to target iOS below 11, MacOS below 10.13 and Web platform. JavaScript must be enabled in order to work.
  ///In this case the [url] parameter is ignored.
  ///
  ///**NOTE for iOS below 11.0 and MacOS below 10.13**: All the cookies returned this way will have all the properties to `null` except for [Cookie.name] and [Cookie.value].
  ///If [webViewController] is `null` or JavaScript is disabled for it, it will try to use a [AndroidHeadlessInAppWebView]
  ///to get the cookie (session-only cookie and cookie with `isHttpOnly` enabled won't be found!).
  ///
  ///**NOTE for Web**: this method will have effect only if the iframe has the same origin.
  ///If [webViewController] is `null` or JavaScript is disabled for it, it will try to use a [AndroidHeadlessInAppWebView]
  ///to get the cookie (session-only cookie and cookie with `isHttpOnly` enabled won't be found!).
  ///
  ///**Supported Platforms/Implementations**:
  ///- Android native WebView
  ///- iOS
  ///- MacOS
  ///- Web
  @override
  Future<Cookie?> getCookie(
      {required WebUri url,
      required String name,
      @Deprecated("Use webViewController instead")
      PlatformInAppWebViewController? iosBelow11WebViewController,
      PlatformInAppWebViewController? webViewController}) async {
    assert(url.toString().isNotEmpty);
    assert(name.isNotEmpty);

    webViewController = webViewController ?? iosBelow11WebViewController;

    if (await _shouldUseJavascript()) {
      List<Cookie> cookies = await _getCookiesWithJavaScript(
          url: url, webViewController: webViewController);
      return cookies
          .cast<Cookie?>()
          .firstWhere((cookie) => cookie!.name == name, orElse: () => null);
    }

    Map<String, dynamic> args = <String, dynamic>{};
    args.putIfAbsent('url', () => url.toString());
    List<dynamic> cookies =
        await channel?.invokeMethod<List>('getCookies', args) ?? [];
    cookies = cookies.cast<Map<dynamic, dynamic>>();
    for (var i = 0; i < cookies.length; i++) {
      cookies[i] = cookies[i].cast<String, dynamic>();
      if (cookies[i]["name"] == name)
        return Cookie(
            name: cookies[i]["name"],
            value: cookies[i]["value"],
            expiresDate: cookies[i]["expiresDate"],
            isSessionOnly: cookies[i]["isSessionOnly"],
            domain: cookies[i]["domain"],
            sameSite: HTTPCookieSameSitePolicy.fromNativeValue(
                cookies[i]["sameSite"]),
            isSecure: cookies[i]["isSecure"],
            isHttpOnly: cookies[i]["isHttpOnly"],
            path: cookies[i]["path"]);
    }
    return null;
  }

  ///Removes a cookie by its [name] for the given [url], [domain] and [path].
  ///
  ///The default value of [path] is `"/"`.
  ///
  ///[webViewController] is used for deleting the cookie (also session-only cookie) using JavaScript (cookie with `isHttpOnly` enabled cannot be deleted, see: https://developer.mozilla.org/en-US/docs/Web/HTTP/Cookies#restrict_access_to_cookies)
  ///from the current context of the [WebView] managed by that controller when you need to target iOS below 11, MacOS below 10.13 and Web platform. JavaScript must be enabled in order to work.
  ///In this case the [url] parameter is ignored.
  ///
  ///**NOTE for iOS below 11.0 and MacOS below 10.13**: If [webViewController] is `null` or JavaScript is disabled for it, it will try to use a [AndroidHeadlessInAppWebView]
  ///to delete the cookie (session-only cookie and cookie with `isHttpOnly` enabled won't be deleted!).
  ///
  ///**NOTE for Web**: this method will have effect only if the iframe has the same origin.
  ///If [webViewController] is `null` or JavaScript is disabled for it, it will try to use a [AndroidHeadlessInAppWebView]
  ///to delete the cookie (session-only cookie and cookie with `isHttpOnly` enabled won't be deleted!).
  ///
  ///**Supported Platforms/Implementations**:
  ///- Android native WebView
  ///- iOS ([Official API - WKHTTPCookieStore.delete](https://developer.apple.com/documentation/webkit/wkhttpcookiestore/2882009-delete)
  ///- MacOS ([Official API - WKHTTPCookieStore.delete](https://developer.apple.com/documentation/webkit/wkhttpcookiestore/2882009-delete)
  ///- Web
  @override
  Future<void> deleteCookie(
      {required WebUri url,
      required String name,
      String path = "/",
      String? domain,
      @Deprecated("Use webViewController instead")
      PlatformInAppWebViewController? iosBelow11WebViewController,
      PlatformInAppWebViewController? webViewController}) async {
    assert(url.toString().isNotEmpty);
    assert(name.isNotEmpty);

    webViewController = webViewController ?? iosBelow11WebViewController;

    if (await _shouldUseJavascript()) {
      await _setCookieWithJavaScript(
          url: url,
          name: name,
          value: "",
          path: path,
          domain: domain,
          maxAge: -1,
          webViewController: webViewController);
      return;
    }

    Map<String, dynamic> args = <String, dynamic>{};
    args.putIfAbsent('url', () => url.toString());
    args.putIfAbsent('name', () => name);
    args.putIfAbsent('domain', () => domain);
    args.putIfAbsent('path', () => path);
    await channel?.invokeMethod('deleteCookie', args);
  }

  ///Removes all cookies for the given [url], [domain] and [path].
  ///
  ///The default value of [path] is `"/"`.
  ///
  ///[webViewController] is used for deleting the cookies (also session-only cookies) using JavaScript (cookies with `isHttpOnly` enabled cannot be deleted, see: https://developer.mozilla.org/en-US/docs/Web/HTTP/Cookies#restrict_access_to_cookies)
  ///from the current context of the [WebView] managed by that controller when you need to target iOS below 11, MacOS below 10.13 and Web platform. JavaScript must be enabled in order to work.
  ///In this case the [url] parameter is ignored.
  ///
  ///**NOTE for iOS below 11.0 and MacOS below 10.13**: If [webViewController] is `null` or JavaScript is disabled for it, it will try to use a [AndroidHeadlessInAppWebView]
  ///to delete the cookies (session-only cookies and cookies with `isHttpOnly` enabled won't be deleted!).
  ///
  ///**NOTE for Web**: this method will have effect only if the iframe has the same origin.
  ///If [webViewController] is `null` or JavaScript is disabled for it, it will try to use a [AndroidHeadlessInAppWebView]
  ///to delete the cookies (session-only cookies and cookies with `isHttpOnly` enabled won't be deleted!).
  ///
  ///**Supported Platforms/Implementations**:
  ///- Android native WebView
  ///- iOS
  ///- MacOS
  ///- Web
  @override
  Future<void> deleteCookies(
      {required WebUri url,
      String path = "/",
      String? domain,
      @Deprecated("Use webViewController instead")
      PlatformInAppWebViewController? iosBelow11WebViewController,
      PlatformInAppWebViewController? webViewController}) async {
    assert(url.toString().isNotEmpty);

    webViewController = webViewController ?? iosBelow11WebViewController;

    if (await _shouldUseJavascript()) {
      List<Cookie> cookies = await _getCookiesWithJavaScript(
          url: url, webViewController: webViewController);
      for (var i = 0; i < cookies.length; i++) {
        await _setCookieWithJavaScript(
            url: url,
            name: cookies[i].name,
            value: "",
            path: path,
            domain: domain,
            maxAge: -1,
            webViewController: webViewController);
      }
      return;
    }

    Map<String, dynamic> args = <String, dynamic>{};
    args.putIfAbsent('url', () => url.toString());
    args.putIfAbsent('domain', () => domain);
    args.putIfAbsent('path', () => path);
    await channel?.invokeMethod('deleteCookies', args);
  }

  ///Removes all cookies.
  ///
  ///**NOTE for iOS**: available from iOS 11.0+.
  ///
  ///**NOTE for MacOS**: available from iOS 10.13+.
  ///
  ///**Supported Platforms/Implementations**:
  ///- Android native WebView ([Official API - CookieManager.removeAllCookies](https://developer.android.com/reference/android/webkit/CookieManager#removeAllCookies(android.webkit.ValueCallback%3Cjava.lang.Boolean%3E)))
  ///- iOS ([Official API - WKWebsiteDataStore.removeData](https://developer.apple.com/documentation/webkit/wkwebsitedatastore/1532938-removedata))
  ///- MacOS ([Official API - WKWebsiteDataStore.removeData](https://developer.apple.com/documentation/webkit/wkwebsitedatastore/1532938-removedata))
  @override
  Future<void> deleteAllCookies() async {
    Map<String, dynamic> args = <String, dynamic>{};
    await channel?.invokeMethod('deleteAllCookies', args);
  }

  ///Fetches all stored cookies.
  ///
  ///**NOTE for iOS**: available on iOS 11.0+.
  ///
  ///**NOTE for MacOS**: available from iOS 10.13+.
  ///
  ///**Supported Platforms/Implementations**:
  ///- iOS ([Official API - WKHTTPCookieStore.getAllCookies](https://developer.apple.com/documentation/webkit/wkhttpcookiestore/2882005-getallcookies))
  ///- MacOS ([Official API - WKHTTPCookieStore.getAllCookies](https://developer.apple.com/documentation/webkit/wkhttpcookiestore/2882005-getallcookies))
  @override
  Future<List<Cookie>> getAllCookies() async {
    List<Cookie> cookies = [];

    Map<String, dynamic> args = <String, dynamic>{};
    List<dynamic> cookieListMap =
        await channel?.invokeMethod<List>('getAllCookies', args) ?? [];
    cookieListMap = cookieListMap.cast<Map<dynamic, dynamic>>();

    cookieListMap.forEach((cookieMap) {
      cookies.add(Cookie(
          name: cookieMap["name"],
          value: cookieMap["value"],
          expiresDate: cookieMap["expiresDate"],
          isSessionOnly: cookieMap["isSessionOnly"],
          domain: cookieMap["domain"],
          sameSite:
              HTTPCookieSameSitePolicy.fromNativeValue(cookieMap["sameSite"]),
          isSecure: cookieMap["isSecure"],
          isHttpOnly: cookieMap["isHttpOnly"],
          path: cookieMap["path"]));
    });
    return cookies;
  }

  Future<String> _getCookieExpirationDate(int expiresDate) async {
    var platformUtil = PlatformUtil.instance();
    var dateTime = DateTime.fromMillisecondsSinceEpoch(expiresDate).toUtc();
    return !kIsWeb
        ? await platformUtil.formatDate(
            date: dateTime,
            format: 'EEE, dd MMM yyyy hh:mm:ss z',
            locale: 'en_US',
            timezone: 'GMT')
        : await platformUtil.getWebCookieExpirationDate(date: dateTime);
  }

  Future<bool> _shouldUseJavascript() async {
    if (Util.isWeb) {
      return true;
    }
    if (Util.isIOS || Util.isMacOS) {
      final platformUtil = PlatformUtil.instance();
      final systemVersion = await platformUtil.getSystemVersion();
      return Util.isIOS
          ? systemVersion.compareTo("11") == -1
          : systemVersion.compareTo("10.13") == -1;
    }
    return false;
  }

  @override
  void dispose() {
    // empty
  }
}

extension InternalCookieManager on AndroidCookieManager {
  get handleMethod => _handleMethod;
}
