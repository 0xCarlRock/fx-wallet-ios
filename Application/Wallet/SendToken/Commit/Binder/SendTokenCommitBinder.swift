import RxSwift
import SwiftyJSON
import WKKit
extension SendTokenCommitViewController {
    class RecommendReceiverCell: FxTableViewCell {
        lazy var view = ItemView(frame: ScreenBounds)
        override func getView() -> UIView { view }
    }

    class RecommendReceiverBinder: NSObject, UITableViewDataSource, UITableViewDelegate {
        init(view: UITableView) {
            self.view = view
            super.init()
        }

        let view: UITableView
        private lazy var recentSection = SectionView(frame: CGRect(x: 0, y: 0, width: ScreenWidth, height: 69.auto()), text: TR("Recents"))
        private lazy var suggestedSection = SectionView(frame: CGRect(x: 0, y: 0, width: ScreenWidth, height: 69.auto()), text: TR("Suggested"))
        private var coin: Coin!
        private var wallet: WKWallet!
        private var items: [[User]] = []
        private lazy var noRecentsCell = NoRecentsCell(style: .default, reuseIdentifier: "")
        var didSeleted: ((User) -> Void)?
        func bind(wallet: Wallet, coin: Coin) {
            self.coin = coin
            self.wallet = wallet.wk
            let receiverList = self.wallet.receivers(forCoin: coin)
            if receiverList.recents.isNotEmpty {
                items = [receiverList.recents, receiverList.receivers]
            } else {
                items = [[.empty]]
            }
            view.register(RecommendReceiverCell.self, forCellReuseIdentifier: "cell")
            view.delegate = self
            view.dataSource = self
        }

        func numberOfSections(in _: UITableView) -> Int {
            return items.count
        }

        func tableView(_: UITableView, heightForHeaderInSection _: Int) -> CGFloat { return 69.auto() }
        func tableView(_: UITableView, viewForHeaderInSection section: Int) -> UIView? {
            return section == 0 ? recentSection : suggestedSection
        }

        func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
            return items[section].count
        }

        func tableView(_: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
            let user = items[indexPath.section][indexPath.row]
            return user.isEmpty ? 92.auto() : 62.auto()
        }

        func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            let all = items[indexPath.section]
            let user = all[indexPath.row]
            if user.isEmpty { return noRecentsCell }
            let cell = tableView.dequeueReusableCell(withIdentifier: "cell") as! RecommendReceiverCell
            cell.view.textLabel.text = user.name.isNotEmpty ? "@\(user.name)" : user.address
            cell.view.addCorner(top: indexPath.row == 0, bottom: indexPath.row == all.count - 1)
            return cell
        }

        func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
            let user = items[indexPath.section][indexPath.row]
            if user.isEmpty { return }
            didSeleted?(user)
        }
    }
}

extension SendTokenCommitViewController {
    class UserNameListBinder: RxObject {
        init(view: WKTableView) { self.view = view }
        let view: WKTableView
        private var coin: Coin!
        private var wallet: WKWallet!
        private var users: [User] = []
        private var items: [NameCellViewModel] = []
        var didSeleted: ((User) -> Void)?
        func bind(wallet: Wallet, coin: Coin, input: UITextField) {
            self.coin = coin
            self.wallet = wallet.wk
            for user in self.wallet.receivers(forCoin: coin).receivers {
                if user.name.isEmpty || user.address.isEmpty { continue }
                users.append(user)
            }
            weak var welf = self
            input.rx.text.subscribe(onNext: { v in
                guard let this = welf else { return }
                let text = v ?? ""
                var display = text.hasPrefix("@") && input.isFirstResponder
                if display {
                    var items: [NameCellViewModel] = []
                    let keyword = text.substring(from: 1)
                    for item in this.users {
                        if text == "@" || item.name.contains(keyword) {
                            items.append(NameCellViewModel(user: item, keyword: keyword))
                        }
                    }
                    display = items.isNotEmpty
                    this.items = items
                    this.view.reloadData()
                }
                this.view.isHidden = !display
            }).disposed(by: defaultBag)
            view.viewModels = { _ in NSMutableArray.viewModels(from: welf?.items, NameCell.self) }
            view.didSeletedBlock = { _, i in
                guard let this = welf else { return }
                input.resignFirstResponder()
                this.didSeleted?(this.items[i.row].user)
            }
        }
    }

    class NameCellViewModel {
        let user: User
        let keyword: String
        init(user: User, keyword: String) {
            self.user = user
            self.keyword = keyword
        }
    }

    class NameCell: FxTableViewCell {
        let nameLabel = UILabel(font: XWallet.Font(ofSize: 16), textColor: HDA(0x838498)).then { $0.autoFont = true }
        override func bind(_ viewModel: Any?) {
            guard let vm = viewModel as? NameCellViewModel else { return }
            let text = "@\(vm.user.name)"
            let attText = NSMutableAttributedString(string: text, attributes: [.foregroundColor: HDA(0x838498), .font: XWallet.Font(ofSize: 16)])
            attText.addAttributes([.foregroundColor: COLOR.title], range: NSRange(location: 0, length: 1))
            if vm.keyword.isNotEmpty {
                attText.addAttributes([.foregroundColor: COLOR.title], range: text.convert(range: text.range(of: vm.keyword)!))
            }
            nameLabel.attributedText = attText
            nameLabel.autoFont = true
        }

        override class func height(model _: Any?) -> CGFloat { 37.auto() }
        override func layoutUI() {
            contentView.addSubview(nameLabel)
            nameLabel.snp.makeConstraints { make in
                make.left.equalTo(48.auto())
                make.centerY.equalToSuperview()
            }
        }
    }
}
