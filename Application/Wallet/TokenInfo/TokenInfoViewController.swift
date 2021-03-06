
import Hero
import RxCocoa
import RxSwift
import WKKit
import XLPagerTabStrip
extension WKWrapper where Base == TokenInfoViewController {
    var view: TokenInfoViewController.View { return base.view as! TokenInfoViewController.View }
}

extension TokenInfoViewController {
    override class func instance(with context: [String: Any]) -> UIViewController? {
        guard let wallet = context["wallet"] as? WKWallet,
            let coin = context["coin"] as? Coin else { return nil }
        return TokenInfoViewController(wallet: wallet, coin: coin)
    }
}

class TokenInfoViewController: WKViewController {
    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }
    init(wallet: WKWallet, coin: Coin) {
        self.coin = coin
        self.wallet = wallet
        super.init(nibName: nil, bundle: nil)
        bindHero()
    }

    let coin: Coin
    let wallet: WKWallet
    private var header: HeaderCell { wk.view.headerCell }
    private lazy var footer = FooterCell(pageBinder.view)
    private lazy var pageBinder = TokenInfoPageViewController(wallet: wallet, coin: coin)
    private var viewModel: TokenInfoPageViewController.ViewModel { pageBinder.viewModel }
    override func loadView() { view = View(frame: ScreenBounds) }
    override func viewDidLoad() {
        super.viewDidLoad()
        logWhenDeinit()
        bindHeader()
        bindListView()
        fetchData()
    }

    override func bindNavBar() {
        super.bindNavBar()
        navigationBar.inch(.iFull)?.setCorner(radius: 36.auto())
        navigationBar.hideLine()
        navigationBar.action(.title, title: coin.name)
        if !coin.isETH {
            navigationBar.action(.right, imageName: "ic_trash") { [weak self] in
                guard let this = self else { return }
                Router.showRemoveToken(wallet: this.wallet.rawValue, coin: this.coin)
            }
        }
        navigationBar.action(.left, imageName: "ic_back_60") { [weak self] in
            Router.pop(self)
        }
    }

    private func bindHeader() {
        predisplay()
        bindMutilExchangeRate()
        header.tokenIV.setImage(urlString: coin.imgUrl, placeHolderImage: coin.imgPlaceholder)
        let coin = self.coin
        weak var welf = self
        viewModel.rankText.asDriver()
            .drive(header.rankLabel.rx.text)
            .disposed(by: defaultBag)
        viewModel.rateText.asDriver()
            .drive(header.cmcRateLabel.rx.attributedText)
            .disposed(by: defaultBag)
        viewModel.priceText.asDriver()
            .drive(header.cmcPriceLabel.rx.text)
            .disposed(by: defaultBag)
        viewModel.marketText.asDriver()
            .drive(header.marketLabel.rx.text)
            .disposed(by: defaultBag)
        viewModel.balance.asDriver()
            .drive(onNext: {
                welf?.header.balanceLabel.wk.set(amount: $0, symbol: coin.symbol, power: coin.decimal, thousandth: 8, mb: true)
            }).disposed(by: defaultBag)
        viewModel.legalBalance.value.asDriver()
            .drive(onNext: { welf?.header.legalBalanceLabel.wk.set(amount: $0, mb: true) })
            .disposed(by: defaultBag)
        viewModel.marketSource
            .map { $0.isEmpty }
            .bind(to: header.infoArrowIV.rx.isHidden)
            .disposed(by: defaultBag)
        header.infoActionButton.action {
            guard let url = welf?.viewModel.marketSource.value, url.isNotEmpty else { return }
            Router.showWebViewController(url: url, push: true)
        }
    }

    private func bindMutilExchangeRate() {
        viewModel.fetchMultiExchangeRate.elements.subscribe(onNext: { [weak self] result in
            for item in result.arrayValue {
                self?.header.updatePriceItem(name: item["exchange"].stringValue, value: item["rate"].stringValue)
            }
            self?.header.startPriceLoopIfNeed()
        }).disposed(by: defaultBag)
    }

    private func predisplay() {
        header.balanceLabel.wk.set(amount: viewModel.balance.value, symbol: coin.symbol, power: coin.decimal, thousandth: 8, mb: true, animated: false)
        header.legalBalanceLabel.wk.set(amount: viewModel.legalBalance.value.value, mb: true, animated: false)
    }

    private func fetchData() {
        pageBinder.refresh()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        navigationBar.isHidden = false
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        pageBinder.viewWillAppear()
    }
}

extension TokenInfoViewController: UITableViewDelegate, UITableViewDataSource {
    private func bindListView() {
        wk.view.listView.delegate = self
        wk.view.listView.dataSource = self
        bindListResponder()
    }

    private func bindListResponder() { let source = pageBinder.listControllers.map { $0.contentOffset.asObservable() }
        Observable.merge(source).subscribe(onNext: { [weak self] offset in
            guard let this = self, let offset = offset else { return }
            if !this.wk.view.listView.isFirstScrollResponder, offset.y <= 0 {
                this.switchScrollResponder(toMainList: true)
            }
        }).disposed(by: defaultBag)
    }

    func scrollViewDidScroll(_: UIScrollView) {
        let listView = wk.view.listView
        if listView.contentOffset.y >= header.estimatedHeight && listView.isFirstScrollResponder {
            switchScrollResponder(toMainList: false)
        }
        if listView.contentOffset.y >= header.estimatedHeight || !listView.isFirstScrollResponder {
            listView.contentOffset = CGPoint(x: 0, y: header.estimatedHeight)
        }
    }

    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int { 2 }
    func tableView(_: UITableView, heightForFooterInSection _: Int) -> CGFloat { return 0.01 }
    func tableView(_: UITableView, heightForHeaderInSection _: Int) -> CGFloat { return 0.01 }
    func tableView(_: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return indexPath.row == 0 ? header.displayHeight : footer.estimatedHeight
    }

    func tableView(_: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return indexPath.row == 0 ? header : footer
    }

    private func switchScrollResponder(toMainList: Bool) {
        wk.view.listView.isFirstScrollResponder = toMainList
        for vc in pageBinder.listControllers {
            vc.listView.isFirstScrollResponder = !toMainList
            if toMainList, vc.listView.contentOffset != .zero {
                DispatchQueue.main.async {
                    vc.listView.contentOffset = .zero
                }
            }
        }
    }
}

extension TokenInfoViewController {
    override func heroAnimator(from: String, to: String) -> WKHeroAnimator? {
        switch (from, to) {
        case ("TokenRootViewController", "TokenInfoViewController"): return animators["0"]
        default: return nil
        }
    }

    private func bindHero() {
        weak var welf = self
        animators["0"] = WKHeroAnimator({ _ in
            Router.tabBarController?.tabBar.hero.modifiers = [.useGlobalCoordinateSpace, .beginWith([.zPosition(100)]), .delay(0.1),
                                                              .translate(y: CGFloat(100.0 * 2.0)), .forceAnimate]
            welf?.navigationBar.titleView?.titleLabel?.hero.id = "token_title_lable"
            welf?.navigationBar.titleView?.titleLabel?.hero.modifiers = [.useScaleBasedSizeChange, .useGlobalCoordinateSpace]
            welf?.navigationBar.hero.modifiers = [.fade, .source(heroID: "token_list_navbar_view"), .useGlobalCoordinateSpace]
            welf?.navigationBar.backgoundView?.alpha = 0
            let headHeroID = "token_list_background"
            welf?.header.aBackgroundView.hero.id = headHeroID
            welf?.header.aBackgroundView.hero.modifiers = [.useGlobalCoordinateSpace]
            welf?.header.contentView.hero.modifiers = [.fade, .useGlobalCoordinateSpace]
            welf?.header.tokenIV.hero.id = "token_image_view"
            welf?.header.tokenInfoBackView.hero.modifiers = [.opacity(0), .source(heroID: headHeroID), .useOptimizedSnapshot]
            welf?.header.tokenInfoContentView.hero.modifiers = [.opacity(0), .useOptimizedSnapshot, .useGlobalCoordinateSpace]
            welf?.header.balanceInfoView.hero.modifiers = [.fade, .useOptimizedSnapshot, .useOptimizedSnapshot]
            welf?.pageBinder.view.hero.modifiers = [.translate(y: 500), .useGlobalCoordinateSpace]
        }, onSuspend: { _ in welf?.navigationBar.backgoundView?.alpha = 1
            Router.tabBarController?.tabBar.hero.modifiers = nil welf?.header.aBackgroundView.hero.id = nil
            welf?.header.aBackgroundView.hero.modifiers = nil
            welf?.header.contentView.hero.modifiers = nil
            welf?.header.tokenIV.hero.id = nil
            welf?.header.tokenInfoBackView.hero.modifiers = nil
            welf?.header.tokenInfoContentView.hero.modifiers = nil
            welf?.header.balanceInfoView.hero.modifiers = nil
            welf?.pageBinder.view.hero.modifiers = nil
            welf?.navigationBar.titleView?.titleLabel?.hero.id = nil
            welf?.navigationBar.leftBarButton?.hero.modifiers = nil
            welf?.navigationBar.rightBarButton?.hero.modifiers = nil
            welf?.navigationBar.hero.modifiers = nil
            welf?.wk.view.tabBarView.hero.modifiers = nil
            welf?.wk.view.tabBarView.image = nil
        })
    }
}
