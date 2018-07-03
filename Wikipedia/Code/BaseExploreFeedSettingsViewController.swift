protocol ExploreFeedSettingsItem {
    var title: String { get }
    var subtitle: String? { get }
    var disclosureType: WMFSettingsMenuItemDisclosureType { get }
    var disclosureText: String? { get }
    var iconName: String? { get }
    var iconColor: UIColor? { get }
    var iconBackgroundColor: UIColor? { get }
    var controlTag: Int { get }
    var isOn: Bool { get }
    func updateSubtitle(for displayType: ExploreFeedSettingsDisplayType)
    func updateDisclosureText(for displayType: ExploreFeedSettingsDisplayType)
    func updateIsOn(for displayType: ExploreFeedSettingsDisplayType)
}

extension ExploreFeedSettingsItem {
    var subtitle: String? { return nil }
    var disclosureType: WMFSettingsMenuItemDisclosureType { return .switch }
    var disclosureText: String? { return nil }
    var iconName: String? { return nil }
    var iconColor: UIColor? { return nil }
    var iconBackgroundColor: UIColor? { return nil }
    func updateSubtitle(for displayType: ExploreFeedSettingsDisplayType) {

    }
    func updateDisclosureText(for displayType: ExploreFeedSettingsDisplayType) {

    }
    func updateIsOn(for displayType: ExploreFeedSettingsDisplayType) {
        
    }
}

enum ExploreFeedSettingsMasterType {
    case entireFeed
    case singleFeedCard(WMFContentGroupKind)
}

private extension WMFContentGroupKind {
    var masterSwitchTitle: String {
        switch self {
        case .news:
            return WMFLocalizedString("explore-feed-preferences-show-news-title", value: "Show In the news card", comment: "Text for the setting that allows users to toggle the visibility of the In the news card")
        case .featuredArticle:
            return WMFLocalizedString("explore-feed-preferences-show-featured-article-title", value: "Show Featured article card", comment: "Text for the setting that allows users to toggle the visibility of the Featured article card")
        case .topRead:
            return WMFLocalizedString("explore-feed-preferences-show-top-read-title", value: "Show Top read card", comment: "Text for the setting that allows users to toggle the visibility of the Top read card")
        case .onThisDay:
            return WMFLocalizedString("explore-feed-preferences-show-on-this-day-title", value: "Show On this day card", comment: "Text for the setting that allows users to toggle the visibility of the On this day card")
        case .pictureOfTheDay:
            return WMFLocalizedString("explore-feed-preferences-show-picture-of-the-day-title", value: "Show Picture of the day card", comment: "Text for the setting that allows users to toggle the visibility of the Picture of the day card")
        case .locationPlaceholder:
            fallthrough
        case .location:
            return WMFLocalizedString("explore-feed-preferences-show-places-title", value: "Show Places card", comment: "Text for the setting that allows users to toggle the visibility of the Places card")
        case .random:
            return WMFLocalizedString("explore-feed-preferences-show-randomizer-title", value: "Show Randomizer card", comment: "Text for the setting that allows users to toggle the visibility of the Randomizer card")
        case .continueReading:
            return WMFLocalizedString("explore-feed-preferences-show-continue-reading-title", value: "Show Continue reading card", comment: "Text for the setting that allows users to toggle the visibility of the Continue reading card")
        case .relatedPages:
            return WMFLocalizedString("explore-feed-preferences-show-related-pages-title", value: "Show Because you read card", comment: "Text for the setting that allows users to toggle the visibility of the Because you read card")
        default:
            assertionFailure("\(self) is not customizable")
            return ""
        }
    }
}

class ExploreFeedSettingsMaster: ExploreFeedSettingsItem {
    let title: String
    let controlTag: Int = -1
    var isOn: Bool = false
    let type: ExploreFeedSettingsMasterType

    init(for type: ExploreFeedSettingsMasterType) {
        self.type = type
        if case let .singleFeedCard(contentGroupKind) = type {
            title = contentGroupKind.masterSwitchTitle
            isOn = contentGroupKind.isInFeed
        } else {
            title = WMFLocalizedString("explore-feed-preferences-turn-off-feed", value: "Turn off Explore tab", comment: "Text for the setting that allows users to turn off Explore tab")
            isOn = UserDefaults.wmf_userDefaults().defaultTabType != .explore
        }
    }

    func updateIsOn(for displayType: ExploreFeedSettingsDisplayType) {
        if case let .singleFeedCard(contentGroupKind) = type {
            isOn = contentGroupKind.isInFeed
        } else {
            isOn = UserDefaults.wmf_userDefaults().defaultTabType != .explore
        }
    }
}

struct ExploreFeedSettingsSection {
    let headerTitle: String?
    let footerTitle: String
    let items: [ExploreFeedSettingsItem]
}

class ExploreFeedSettingsLanguage: ExploreFeedSettingsItem {
    let title: String
    let subtitle: String?
    let controlTag: Int
    var isOn: Bool = false
    let siteURL: URL
    let languageLink: MWKLanguageLink

    init(_ languageLink: MWKLanguageLink, controlTag: Int, displayType: ExploreFeedSettingsDisplayType) {
        self.languageLink = languageLink
        title = languageLink.localizedName
        subtitle = languageLink.languageCode.uppercased()
        self.controlTag = controlTag
        siteURL = languageLink.siteURL()
        updateIsOn(for: displayType)
    }

    func updateIsOn(for displayType: ExploreFeedSettingsDisplayType) {
        switch (displayType) {
        case .singleLanguage:
            return
        case .multipleLanguages:
            isOn = languageLink.isInFeed
        case .detail(let contentGroupKind):
            isOn = languageLink.isInFeed(for: contentGroupKind)
        }
    }
}

struct ExploreFeedSettingsGlobalCards: ExploreFeedSettingsSwitchItem {
    let disclosureType: WMFSettingsMenuItemDisclosureType = .switch
    let title: String = WMFLocalizedString("explore-feed-preferences-global-cards-title", value: "Global cards", comment: "Title for the setting that allows users to toggle non-language specific feed cards")
    let subtitle: String? = WMFLocalizedString("explore-feed-preferences-global-cards-description", value: "Non-language specific cards", comment: "Description of global feed cards")
    let controlTag: Int = -2
    let isOn: Bool = SessionSingleton.sharedInstance().dataStore.feedContentController.areGlobalContentGroupKindsInFeed
}

    func updateIsOn(for displayType: ExploreFeedSettingsDisplayType) {
        guard displayType == .singleLanguage || displayType == .multipleLanguages else {
            return
        }
        isOn = SessionSingleton.sharedInstance().dataStore.feedContentController.areGlobalContentGroupKindsInFeed
    }
}

enum ExploreFeedSettingsDisplayType: Equatable {
    case singleLanguage
    case multipleLanguages
    case detail(WMFContentGroupKind)
}

class BaseExploreFeedSettingsViewController: UIViewController {
    @IBOutlet weak var tableView: UITableView!
    @objc var dataStore: MWKDataStore?
    var theme = Theme.standard
    var indexPathsForCellsThatNeedReloading: [IndexPath] = []

    override var nibName: String? {
        return "BaseExploreFeedSettingsViewController"
    }

    open var displayType: ExploreFeedSettingsDisplayType = .singleLanguage

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(WMFSettingsTableViewCell.wmf_classNib(), forCellReuseIdentifier: WMFSettingsTableViewCell.identifier)
        tableView.register(WMFTableHeaderFooterLabelView.wmf_classNib(), forHeaderFooterViewReuseIdentifier: WMFTableHeaderFooterLabelView.identifier)
        tableView.contentInset = UIEdgeInsets(top: 10, left: 0, bottom: 0, right: 0)
        tableView.sectionFooterHeight = UITableViewAutomaticDimension
        tableView.estimatedSectionFooterHeight = 44
        apply(theme: theme)
        NotificationCenter.default.addObserver(self, selector: #selector(exploreFeedPreferencesDidSave(_:)), name: NSNotification.Name.WMFExploreFeedPreferencesDidSave, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(newExploreFeedPreferencesWereRejected(_:)), name: NSNotification.Name.WMFNewExploreFeedPreferencesWereRejected, object: nil)
    }

    var preferredLanguages: [MWKLanguageLink] {
        return MWKLanguageLinkController.sharedInstance().preferredLanguages
    }

    var languages: [ExploreFeedSettingsLanguage] {
        let languages = preferredLanguages.enumerated().compactMap { (index, languageLink) in
            ExploreFeedSettingsLanguage(languageLink, controlTag: index, isOn: isLanguageSwitchOn(for: languageLink))
        }
        return languages
    }

    var feedContentController: WMFExploreFeedContentController? {
        return dataStore?.feedContentController
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    open func needsReloading(_ item: ExploreFeedSettingsItem) -> Bool {
        assertionFailure("Subclassers should override")
        return false
    }

    open var shouldReload: Bool {
        return true
    }

    open func isLanguageSwitchOn(for languageLink: MWKLanguageLink) -> Bool {
        assertionFailure("Subclassers should override")
        return false
    }

    open var sections: [ExploreFeedSettingsSection] {
        assertionFailure("Subclassers should override")
        return []
    }

    func getItem(at indexPath: IndexPath) -> ExploreFeedSettingsItem {
        let items = getSection(at: indexPath.section).items
        assert(items.indices.contains(indexPath.row), "Item at indexPath \(indexPath) doesn't exist")
        return items[indexPath.row]
    }

    func getSection(at index: Int) -> ExploreFeedSettingsSection {
        assert(sections.indices.contains(index), "Section at index \(index) doesn't exist")
        return sections[index]
    }

    // MARK: - Notifications

    open func reload() {
        guard shouldReload else {
            return
        }
    }

    @objc open func exploreFeedPreferencesDidSave(_ notification: Notification) {
        DispatchQueue.main.async {
            self.reload()
        }
    }

    @objc open func newExploreFeedPreferencesWereRejected(_ notification: Notification) {
        DispatchQueue.main.async {
            self.reload()
        }
    }

}

// MARK: - UITableViewDataSource

extension BaseExploreFeedSettingsViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let section = getSection(at: section)
        return section.items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: WMFSettingsTableViewCell.identifier, for: indexPath) as? WMFSettingsTableViewCell else {
            return UITableViewCell()
        }
        let item = getItem(at: indexPath)
        if needsReloading(item) {
            indexPathsForCellsThatNeedReloading.append(indexPath)
        }
        configureCell(cell, item: item)
        return cell
    }

    private func configureCell(_ cell: WMFSettingsTableViewCell, item: ExploreFeedSettingsItem) {
        cell.configure(item.disclosureType, disclosureText: item.disclosureText, title: item.title, subtitle: item.subtitle, iconName: item.iconName, isSwitchOn: item.isOn, iconColor: item.iconColor, iconBackgroundColor: item.iconBackgroundColor, controlTag: item.controlTag, theme: theme)
        cell.delegate = self
    }
}

// MARK: - UITableViewDelegate

extension BaseExploreFeedSettingsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let section = getSection(at: section)
        return section.headerTitle
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        guard let footer = tableView.dequeueReusableHeaderFooterView(withIdentifier: WMFTableHeaderFooterLabelView.identifier) as? WMFTableHeaderFooterLabelView else {
            return nil
        }
        let section = getSection(at: section)
        footer.setShortTextAsProse(section.footerTitle)
        footer.type = .footer
        if let footer = footer as Themeable? {
            footer.apply(theme: theme)
        }
        return footer
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        guard let _ = self.tableView(tableView, viewForFooterInSection: section) as? WMFTableHeaderFooterLabelView else {
            return 0
        }
        return UITableViewAutomaticDimension
    }
}

// MARK: - WMFSettingsTableViewCellDelegate

extension BaseExploreFeedSettingsViewController: WMFSettingsTableViewCellDelegate {
    open func settingsTableViewCell(_ settingsTableViewCell: WMFSettingsTableViewCell!, didToggleDisclosureSwitch sender: UISwitch!) {
        assertionFailure("Subclassers should override")
    }
}

// MARK: - Themeable

extension BaseExploreFeedSettingsViewController: Themeable {
    func apply(theme: Theme) {
        self.theme = theme
        guard viewIfLoaded != nil else {
            return
        }
        tableView.backgroundColor = theme.colors.baseBackground
    }
}
