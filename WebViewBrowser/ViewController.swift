import UIKit
import WebKit

class ViewController: UIViewController, WKNavigationDelegate, WKUIDelegate {

    // MARK: - 配置项
    /// 两个窗口的默认页面
    private let windowURLs: [String] = [
        "https://github.com",
        "https://dash.cloudflare.com/"
    ]

    /// 窗口标签默认名称
    private let windowTitles: [String] = ["窗口一", "窗口二"]

    /// 标签栏高度
    private let tabBarHeight: CGFloat = 44

    /// 翻译按钮宽度
    private let translateButtonWidth: CGFloat = 52

    // MARK: - UI 组件
    private var tabBar: UIView!
    private var tabButtons: [UIButton] = []
    private var tabIndicator: UIView!
    private var translateButton: UIButton!
    private var webViews: [WKWebView] = []
    private var webViewContainer: UIView!
    private var progressView: UIProgressView!
    private var refreshControls: [UIRefreshControl] = []
    private var panGestures: [UIPanGestureRecognizer] = []

    /// 当前激活的窗口索引
    private var activeIndex: Int = 0

    // MARK: - 手势相关
    private var gestureStartPoint: CGPoint = .zero
    private var gestureStartDate: Date = .init()
    private let gestureThreshold: CGFloat = 80
    private let gestureMaxDuration: TimeInterval = 0.5

    // MARK: - 翻译相关
    private var translateToolbar: UIView?
    private var isTranslated: [Bool] = [false, false]

    // MARK: - 生命周期
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupTabBar()
        setupWebViewContainer()
        setupWebViews()
        setupProgressView()
        setupRefreshControls()
        setupGestures()
        switchToTab(index: 0)
        loadInitialPages()
    }

    override var prefersStatusBarHidden: Bool { false }
    override var preferredStatusBarStyle: UIStatusBarStyle { .darkContent }

    // MARK: - 标签栏
    private func setupTabBar() {
        tabBar = UIView()
        tabBar.backgroundColor = .systemGray6
        tabBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tabBar)

        NSLayoutConstraint.activate([
            tabBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tabBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tabBar.heightAnchor.constraint(equalToConstant: tabBarHeight)
        ])

        // 翻译按钮（右侧）
        translateButton = UIButton(type: .system)
        translateButton.setTitle("译", for: .normal)
        translateButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
        translateButton.backgroundColor = .systemBlue
        translateButton.setTitleColor(.white, for: .normal)
        translateButton.layer.cornerRadius = 8
        translateButton.translatesAutoresizingMaskIntoConstraints = false
        translateButton.addTarget(self, action: #selector(translateTapped), for: .touchUpInside)
        tabBar.addSubview(translateButton)

        NSLayoutConstraint.activate([
            translateButton.trailingAnchor.constraint(equalTo: tabBar.trailingAnchor, constant: -8),
            translateButton.centerYAnchor.constraint(equalTo: tabBar.centerYAnchor),
            translateButton.widthAnchor.constraint(equalToConstant: translateButtonWidth),
            translateButton.heightAnchor.constraint(equalToConstant: 32)
        ])

        // 标签按钮容器
        let tabsStack = UIStackView()
        tabsStack.axis = .horizontal
        tabsStack.distribution = .fillEqually
        tabsStack.spacing = 4
        tabsStack.translatesAutoresizingMaskIntoConstraints = false
        tabBar.addSubview(tabsStack)

        NSLayoutConstraint.activate([
            tabsStack.leadingAnchor.constraint(equalTo: tabBar.leadingAnchor, constant: 8),
            tabsStack.trailingAnchor.constraint(equalTo: translateButton.leadingAnchor, constant: -8),
            tabsStack.centerYAnchor.constraint(equalTo: tabBar.centerYAnchor),
            tabsStack.heightAnchor.constraint(equalToConstant: 32)
        ])

        for (index, title) in windowTitles.enumerated() {
            let button = UIButton(type: .system)
            button.setTitle(title, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
            button.tag = index
            button.layer.cornerRadius = 8
            button.addTarget(self, action: #selector(tabTapped(_:)), for: .touchUpInside)
            tabsStack.addArrangedSubview(button)
            tabButtons.append(button)
        }

        // 选中指示条
        tabIndicator = UIView()
        tabIndicator.backgroundColor = .systemBlue
        tabIndicator.layer.cornerRadius = 2
        tabIndicator.translatesAutoresizingMaskIntoConstraints = false
        tabBar.addSubview(tabIndicator)
    }

    @objc private func tabTapped(_ sender: UIButton) {
        switchToTab(index: sender.tag)
    }

    private func switchToTab(index: Int) {
        activeIndex = index
        for (i, button) in tabButtons.enumerated() {
            if i == index {
                button.backgroundColor = .systemBackground
                button.setTitleColor(.label, for: .normal)
                button.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
            } else {
                button.backgroundColor = .clear
                button.setTitleColor(.secondaryLabel, for: .normal)
                button.titleLabel?.font = .systemFont(ofSize: 14, weight: .regular)
            }
        }
        // 切换 WebView 显示
        for (i, webView) in webViews.enumerated() {
            webView.isHidden = (i != index)
        }
        // 更新进度条
        updateProgressView()
        // 更新翻译按钮状态
        updateTranslateButtonState()
    }

    private func updateTabTitle(index: Int, title: String) {
        guard index < tabButtons.count else { return }
        let displayTitle = title.count > 8 ? String(title.prefix(8)) + "…" : title
        tabButtons[index].setTitle(displayTitle, for: .normal)
    }

    // MARK: - WebView 容器
    private func setupWebViewContainer() {
        webViewContainer = UIView()
        webViewContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webViewContainer)

        NSLayoutConstraint.activate([
            webViewContainer.topAnchor.constraint(equalTo: tabBar.bottomAnchor),
            webViewContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webViewContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webViewContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupWebViews() {
        for i in 0..<2 {
            let config = WKWebViewConfiguration()
            config.allowsInlineMediaPlayback = true
            config.mediaTypesRequiringUserActionForPlayback = []
            // 允许在页面中执行 JavaScript（翻译功能需要）
            config.defaultWebpagePreferences.allowsContentJavaScript = true

            let webView = WKWebView(frame: .zero, configuration: config)
            webView.navigationDelegate = self
            webView.uiDelegate = self
            webView.allowsBackForwardNavigationGestures = false
            webView.translatesAutoresizingMaskIntoConstraints = false
            webView.scrollView.bounces = true
            webView.isHidden = (i != 0)
            webViewContainer.addSubview(webView)

            NSLayoutConstraint.activate([
                webView.topAnchor.constraint(equalTo: webViewContainer.topAnchor),
                webView.leadingAnchor.constraint(equalTo: webViewContainer.leadingAnchor),
                webView.trailingAnchor.constraint(equalTo: webViewContainer.trailingAnchor),
                webView.bottomAnchor.constraint(equalTo: webViewContainer.bottomAnchor)
            ])

            webView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)
            webViews.append(webView)
        }
    }

    private func loadInitialPages() {
        for (index, urlString) in windowURLs.enumerated() {
            guard let url = URL(string: urlString) else { continue }
            webViews[index].load(URLRequest(url: url))
        }
    }

    private var currentWebView: WKWebView {
        webViews[activeIndex]
    }

    // MARK: - 进度条
    private func setupProgressView() {
        progressView = UIProgressView(progressViewStyle: .default)
        progressView.progressTintColor = .systemBlue
        progressView.trackTintColor = .clear
        progressView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(progressView)

        NSLayoutConstraint.activate([
            progressView.topAnchor.constraint(equalTo: tabBar.bottomAnchor),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 2)
        ])
    }

    private func updateProgressView() {
        let progress = currentWebView.estimatedProgress
        progressView.progress = Float(progress)
        progressView.isHidden = progress >= 1.0
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == #keyPath(WKWebView.estimatedProgress),
           let webView = object as? WKWebView,
           webView === currentWebView {
            updateProgressView()
        }
    }

    // MARK: - 下拉刷新
    private func setupRefreshControls() {
        for webView in webViews {
            let refresh = UIRefreshControl()
            refresh.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
            webView.scrollView.addSubview(refresh)
            refreshControls.append(refresh)
        }
    }

    @objc private func handleRefresh() {
        currentWebView.reload()
    }

    // MARK: - 手势导航
    private func setupGestures() {
        for webView in webViews {
            let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            pan.delegate = self
            pan.cancelsTouchesInView = false
            webView.addGestureRecognizer(pan)
            panGestures.append(pan)
        }
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard gesture.view === currentWebView else { return }
        let location = gesture.location(in: view)
        let translation = gesture.translation(in: view)

        switch gesture.state {
        case .began:
            gestureStartPoint = location
            gestureStartDate = Date()
        case .ended:
            let elapsed = Date().timeIntervalSince(gestureStartDate)
            let horizontalDistance = translation.x
            let verticalDistance = abs(translation.y)

            guard elapsed <= gestureMaxDuration,
                  abs(horizontalDistance) > gestureThreshold,
                  abs(horizontalDistance) > verticalDistance * 1.5 else {
                return
            }

            if horizontalDistance > 0 {
                if currentWebView.canGoForward {
                    currentWebView.goForward()
                }
            } else {
                if currentWebView.canGoBack {
                    currentWebView.goBack()
                }
            }
        default:
            break
        }
    }

    // MARK: - 全局翻译功能
    @objc private func translateTapped() {
        if isTranslated[activeIndex] {
            // 已翻译 → 恢复原文（刷新页面）
            currentWebView.reload()
            isTranslated[activeIndex] = false
            updateTranslateButtonState()
        } else {
            // 未翻译 → 注入翻译脚本
            injectTranslateScript()
        }
    }

    private func updateTranslateButtonState() {
        if isTranslated[activeIndex] {
            translateButton.backgroundColor = .systemGreen
            translateButton.setTitle("原", for: .normal)
        } else {
            translateButton.backgroundColor = .systemBlue
            translateButton.setTitle("译", for: .normal)
        }
    }

    private func injectTranslateScript() {
        let javascript = """
        (function() {
            if (document.getElementById('__webplus_translate_bar__')) {
                document.getElementById('__webplus_translate_bar__').remove();
            }

            // 创建浮动翻译工具栏
            var bar = document.createElement('div');
            bar.id = '__webplus_translate_bar__';
            bar.style.cssText = 'position:fixed;top:0;left:0;right:0;z-index:2147483647;background:#fff;border-bottom:1px solid #ddd;padding:8px 12px;display:flex;align-items:center;gap:8px;box-shadow:0 2px 8px rgba(0,0,0,0.15);font-family:-apple-system,sans-serif;';

            var title = document.createElement('span');
            title.textContent = '翻译为：';
            title.style.cssText = 'font-size:14px;color:#333;font-weight:500;';

            var langs = [
                {code:'zh-CN', name:'中文'},
                {code:'en', name:'English'},
                {code:'ja', name:'日本語'},
                {code:'ko', name:'한국어'},
                {code:'zh-TW', name:'繁體'}
            ];

            langs.forEach(function(lang) {
                var btn = document.createElement('button');
                btn.textContent = lang.name;
                btn.style.cssText = 'padding:4px 10px;font-size:13px;border:1px solid #007aff;background:#fff;color:#007aff;border-radius:6px;cursor:pointer;';
                btn.onmouseover = function(){ this.style.background='#007aff'; this.style.color='#fff'; };
                btn.onmouseout = function(){ this.style.background='#fff'; this.style.color='#007aff'; };
                btn.onclick = function() {
                    doTranslate(lang.code);
                    bar.style.display = 'none';
                };
                bar.appendChild(btn);
            });

            var closeBtn = document.createElement('button');
            closeBtn.textContent = '✕';
            closeBtn.style.cssText = 'margin-left:auto;padding:4px 8px;font-size:14px;border:none;background:transparent;color:#999;cursor:pointer;';
            closeBtn.onclick = function() { bar.remove(); };

            bar.appendChild(title);
            bar.appendChild(closeBtn);
            document.body.appendChild(bar);
            document.body.style.paddingTop = '44px';

            function doTranslate(targetLang) {
                // 移除旧的翻译元素
                var old = document.getElementById('google_translate_element');
                if (old) old.remove();
                var oldScript = document.getElementById('google_translate_script');
                if (oldScript) oldScript.remove();

                var div = document.createElement('div');
                div.id = 'google_translate_element';
                div.style.cssText = 'display:none;';
                document.body.appendChild(div);

                window.googleTranslateElementInit = function() {
                    new google.translate.TranslateElement({
                        pageLanguage: 'auto',
                        includedLanguages: 'zh-CN,en,ja,ko,zh-TW,fr,de,es,ru,ar',
                        layout: google.translate.TranslateElement.InlineLayout.SIMPLE,
                        autoDisplay: false
                    }, 'google_translate_element');
                    // 自动选择目标语言
                    setTimeout(function() {
                        var selects = document.querySelectorAll('.goog-te-combo');
                        selects.forEach(function(sel) {
                            sel.value = targetLang;
                            sel.dispatchEvent(new Event('change'));
                        });
                    }, 500);
                };

                var script = document.createElement('script');
                script.id = 'google_translate_script';
                script.src = '//translate.google.com/translate_a/element.js?cb=googleTranslateElementInit';
                document.head.appendChild(script);
            }
        })();
        """

        currentWebView.evaluateJavaScript(javascript) { [weak self] result, error in
            if let error = error {
                print("翻译脚本注入失败: \(error.localizedDescription)")
                // 降级方案：跳转到 Google 翻译代理
                self?.fallbackTranslate()
            } else {
                self?.isTranslated[self?.activeIndex ?? 0] = true
                self?.updateTranslateButtonState()
            }
        }
    }

    private func fallbackTranslate() {
        // 降级方案：通过 Google 翻译代理加载页面
        guard let currentURL = currentWebView.url?.absoluteString else { return }
        let encodedURL = currentURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? currentURL
        let translateURL = "https://translate.google.com/translate?sl=auto&tl=zh-CN&u=\(encodedURL)"
        if let url = URL(string: translateURL) {
            currentWebView.load(URLRequest(url: url))
            isTranslated[activeIndex] = true
            updateTranslateButtonState()
        }
    }

    // MARK: - WKNavigationDelegate
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // 结束下拉刷新
        if let index = webViews.firstIndex(of: webView), index < refreshControls.count {
            refreshControls[index].endRefreshing()
        }
        // 更新标签标题
        if let index = webViews.firstIndex(of: webView), let title = webView.title {
            updateTabTitle(index: index, title: title)
        }
        // 页面加载后重置翻译状态（新页面需要重新翻译）
        if let index = webViews.firstIndex(of: webView) {
            isTranslated[index] = false
            if index == activeIndex {
                updateTranslateButtonState()
            }
        }
        if webView === currentWebView {
            progressView.isHidden = true
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        if let index = webViews.firstIndex(of: webView), index < refreshControls.count {
            refreshControls[index].endRefreshing()
        }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if let index = webViews.firstIndex(of: webView), index < refreshControls.count {
            refreshControls[index].endRefreshing()
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(.allow)
    }

    // MARK: - WKUIDelegate
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }

    deinit {
        for webView in webViews {
            webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress))
        }
    }
}

// MARK: - UIGestureRecognizerDelegate
extension ViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
        let velocity = pan.velocity(in: view)
        return abs(velocity.x) > abs(velocity.y) * 1.2
    }
}
