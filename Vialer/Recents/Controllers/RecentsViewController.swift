//
//  RecentsViewController.swift
//  Copyright © 2017 VoIPGRID. All rights reserved.
//

import UIKit
import CoreData

class RecentsViewController: UIViewController, SegueHandler, TableViewHandler {

    // MARK: - Configuration
    enum SegueIdentifier: String {
        case sipCalling = "SIPCallingSegue"
        case twoStepCalling = "TwoStepCallingSegue"
        case reachabilityBar = "ReachabilityBarSegue"
    }
    enum CellIdentifier: String {
        case errorText = "CellWithErrorText"
        case recentCall = "RecentCallCell"
    }
    fileprivate struct Config {
        struct ReachabilityBar {
            static let height: CGFloat = 30.0
            static let animationDuration = 0.3
        }
    }

    // MARK: - Dependency Injection
    var currentUser = SystemUser.current()!
    var defaultConfiguration = Configuration.default()
    var contactModel = ContactModel.defaultModel
    private lazy var managedObjectContext: NSManagedObjectContext = {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        return appDelegate.managedObjectContext
    }()

    fileprivate lazy var callManager: RecentCallManager = {
        let manager = RecentCallManager()
        manager.mainManagedObjectContext = self.managedObjectContext
        return manager
    }()

    // MARK: - Properties
    fileprivate lazy var fetchedResultController: NSFetchedResultsController<RecentCall> = {
        let fetchRequest = NSFetchRequest<RecentCall>()
        let entity = NSEntityDescription.entity(forEntityName: "RecentCall", in: self.managedObjectContext)
        fetchRequest.entity = entity
        let sort = NSSortDescriptor(key: "callDate", ascending: false)
        fetchRequest.sortDescriptors = [sort]
        fetchRequest.fetchBatchSize = 20
        let controller = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self.managedObjectContext, sectionNameKeyPath: nil, cacheName: nil)
        controller.delegate = self
        return controller
    }()
    fileprivate lazy var refreshControl: UIRefreshControl = {
        let control = UIRefreshControl()
        control.attributedTitle = NSAttributedString(string: NSLocalizedString("Fetching the latest recent calls from the server.", comment: "Fetching the latest recent calls from the server."))
        control.addTarget(self, action: #selector(refresh(control:)), for: .valueChanged)
        return control
    }()

    // MARK: - Internal state
    var reachabilityStatus: ReachabilityManagerStatusType = .highSpeed
    var showTitleImage = false
    var phoneNumberToCall: String!

    // MARK: - Initialisation
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupUI()
    }

    // MARK: - Outlets
    @IBOutlet weak var tableView: UITableView! {
        didSet {
            tableView.delegate = self
            tableView.dataSource = self
            tableView.addSubview(refreshControl)
        }
    }
    @IBOutlet weak var filterControl: UISegmentedControl! {
        didSet {
            filterControl.tintColor = defaultConfiguration?.colorConfiguration.color(forKey: ConfigurationRecentsFilterControlTintColor)
        }
    }
    @IBOutlet weak var reachabilityBarHeigthConstraint: NSLayoutConstraint!
}

// MARK: - Lifecycle
extension RecentsViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        showTitleImage = true
        setupLayout()
        do {
            try fetchedResultController.performFetch()
        } catch let error as NSError {
            VialerLogError("Unable to fetch recents from CD: \(error) \(error.userInfo)")
            abort()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        VialerGAITracker.trackScreenForController(name: controllerName)
        tableView.reloadData()
        refreshRecents()
    }
}

// MARK: - Actions
extension RecentsViewController {
    @IBAction func leftDrawerButtonPressed(_ sender: UIBarButtonItem) {
        mm_drawerController.toggle(.left, animated: true, completion: nil)
    }

    @IBAction func filterControlTapped(sender: UISegmentedControl) {
        if sender.selectedSegmentIndex == 1 {
            fetchedResultController.fetchRequest.predicate = NSPredicate(format: "duration == 0 AND inbound == YES")
        } else {
            fetchedResultController.fetchRequest.predicate = nil
        }

        do {
            try fetchedResultController.performFetch()
            tableView.reloadData()
        } catch let error as NSError {
            VialerLogError("Error fetching recents: \(error) \(error.userInfo)")
        }
    }
}

// MARK: - Segues
extension RecentsViewController {
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segueIdentifier(segue: segue) {
        case .twoStepCalling:
            let twoStepCallingVC = segue.destination as! TwoStepCallingViewController
            twoStepCallingVC.handlePhoneNumber(phoneNumberToCall)
        case .sipCalling:
            let sipCallingVC = segue.destination as! SIPCallingViewController
            sipCallingVC.handleOutgoingCall(phoneNumber: phoneNumberToCall, contact: nil)
        case .reachabilityBar:
            let reachabilityBarVC = segue.destination as! ReachabilityBarViewController
            reachabilityBarVC.delegate = self
        }
    }
}

// MARK: - Helper functions
extension RecentsViewController {
    fileprivate func setupUI() {
        title = NSLocalizedString("Recents", comment: "Recents")
        tabBarItem.image = UIImage(asset: .tabRecent)
        tabBarItem.selectedImage = UIImage(asset: .tabRecentActive)
    }

    fileprivate func setupLayout() {
        if showTitleImage {
            navigationItem.titleView = UIImageView(image: UIImage(asset: .logo))
        } else {
            showTitleImage = true
        }
        reachabilityBarHeigthConstraint.constant = 0.0
        navigationController?.view.backgroundColor = defaultConfiguration?.colorConfiguration.color(forKey: ConfigurationNavigationBarBarTintColor)
    }

    fileprivate func call(_ number: String) {
        phoneNumberToCall = number
        if reachabilityStatus == .highSpeed && currentUser.sipEnabled {
            VialerGAITracker.setupOutgoingSIPCallEvent()
            performSegue(segueIdentifier: .sipCalling)
        } else if reachabilityStatus == .offline {
            let alert = UIAlertController(title: NSLocalizedString("No internet connection", comment: "No internet connection"), message: NSLocalizedString("It's not possible to setup a call. Make sure you have an internet connection", comment: "It's not possible to setup a call. Make sure you have an internet connection"), andDefaultButtonText: NSLocalizedString("Ok", comment: "Ok"))!
            present(alert, animated: true, completion: nil)
        } else {
            VialerGAITracker.setupOutgoingConnectABCallEvent()
            performSegue(segueIdentifier: .twoStepCalling)
        }
    }

    fileprivate func showContactViewController(forRecent recent: RecentCall) {
        let contactViewController: CNContactViewController
        let contact: CNContact
        if recent.suppressed() {
            let unknownContact = CNMutableContact()
            unknownContact.givenName = recent.displayName
            contactViewController = CNContactViewController(forUnknownContact: unknownContact)
            contactViewController.allowsEditing = false
        } else if let recordID = recent.callerRecordID {
            contact = contactModel.getContact(for: recordID)!
            contactViewController = CNContactViewController(for: contact)
            contactViewController.title = CNContactFormatter.string(from: contact, style: .fullName)
        } else {
            let newPhoneNumber = recent.inbound!.boolValue ? recent.sourceNumber! : recent.destinationNumber!
            let phoneNumber = CNPhoneNumber(stringValue: newPhoneNumber)
            let phoneNumbers = CNLabeledValue<CNPhoneNumber>(label: CNLabelPhoneNumberMain, value: phoneNumber)
            let unknownContact = CNMutableContact()
            unknownContact.phoneNumbers = [phoneNumbers]
            unknownContact.givenName = recent.displayName
            contactViewController = CNContactViewController(forUnknownContact: unknownContact)
            contactViewController.title = newPhoneNumber
        }

        contactViewController.contactStore = contactModel.contactStore
        contactViewController.allowsActions = false
        contactViewController.delegate = self
        navigationController?.pushViewController(contactViewController, animated: true)
    }

    @objc fileprivate func refresh(control: UIRefreshControl) {
        refreshRecents()
    }

    fileprivate func refreshRecents() {
        guard !callManager.reloading else {
            return
        }
        refreshControl.beginRefreshing()
        DispatchQueue.global(qos: .userInteractive).async {
            self.callManager.getLatestRecentCalls { fetchError in
                DispatchQueue.main.async {
                    self.refreshControl.endRefreshing()
                    if let error = fetchError, self.callManager.recentsFetchErrorCode == .fetchingUserNotAllowed {
                        let alert = UIAlertController(title: NSLocalizedString("Not allowed", comment: "Not allowed"), message: error.localizedDescription, andDefaultButtonText: NSLocalizedString("Ok", comment: "Ok"))!
                        self.present(alert, animated: true, completion: nil)
                    }
                }
            }
        }
    }
}

// MARK: - CNContactViewControllerDelegate
extension RecentsViewController : CNContactViewControllerDelegate {
    func contactViewController(_ viewController: CNContactViewController, shouldPerformDefaultActionFor property: CNContactProperty) -> Bool {
        guard let phoneNumber = (property.value as? CNPhoneNumber)?.stringValue else {
            return true
        }
        /**
         *  We need to return asap to prevent default action (calling with native dialer).
         *  As a workaround, we put the presenting of the new viewcontroller via a separate queue,
         *  which will immediately go back to the main thread.
         */
        DispatchQueue.main.async {
            self.call(phoneNumber)
        }
        return false
    }

    func contactViewController(_ viewController: CNContactViewController, didCompleteWith contact: CNContact?) {
        dismiss(animated: true, completion: nil)
        refreshRecents()
    }
}

// MARK: - UITableViewDelegate
extension RecentsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard fetchedResultController.fetchedObjects?.count != 0 else { return }
        let recent = fetchedResultController.object(at: indexPath)
        guard !recent.suppressed() else { return }
        if recent.inbound!.boolValue {
            call(recent.sourceNumber!)
        } else {
            call(recent.destinationNumber!)
        }
    }

    func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        guard fetchedResultController.fetchedObjects?.count != 0 else { return }
        let recent = fetchedResultController.object(at: indexPath)
        showContactViewController(forRecent: recent)
    }
}

// MARK: - UITableViewDataSource
extension RecentsViewController : UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return max(fetchedResultController.sections?[section].numberOfObjects ?? 1, 1)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if callManager.recentsFetchFailed {
            return failedLoadingRecentsCell(indexPath: indexPath)
        } else if fetchedResultController.fetchedObjects?.count == 0 {
            return noRecentsCell(indexPath: indexPath)
        } else {
            return recentCell(indexPath: indexPath)
        }
    }
}

// MARK: - ReachabilityBarViewControllerDelegate
extension RecentsViewController: ReachabilityBarViewControllerDelegate {
    func reachabilityBar(_ reachabilityBar: ReachabilityBarViewController!, statusChanged status: ReachabilityManagerStatusType) {
        reachabilityStatus = status
    }
    func reachabilityBar(_ reachabilityBar: ReachabilityBarViewController!, shouldBeVisible visible: Bool) {
        view.layoutIfNeeded()
        reachabilityBarHeigthConstraint.constant = visible ? Config.ReachabilityBar.height : 0.0
        UIView.animate(withDuration: Config.ReachabilityBar.animationDuration) {
            self.view.layoutIfNeeded()
        }
    }
}

// MARK: - NSFetchedResultsControllerDelegate
extension RecentsViewController : NSFetchedResultsControllerDelegate {
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.reloadData()
    }
}

// MARK: - Cell configuration
extension RecentsViewController {
    fileprivate func failedLoadingRecentsCell(indexPath: IndexPath) -> UITableViewCell {
        let cell = dequeueReusableCell(cellIdentifier: .errorText, for: indexPath)
        switch callManager.recentsFetchErrorCode {
        case .fetchingUserNotAllowed:
            cell.textLabel?.text = NSLocalizedString("You are not allowed to view recent calls", comment: "You are not allowed to view recent calls")
        default:
            cell.textLabel?.text = NSLocalizedString("Could not load your recent calls", comment: "Could not load your recent calls")
        }
        return cell
    }

    fileprivate func noRecentsCell(indexPath: IndexPath) -> UITableViewCell {
        let noRecents: String
        if filterControl.selectedSegmentIndex == 0 {
            noRecents = NSLocalizedString("No recent calls", comment: "No recent calls")
        } else {
            noRecents = NSLocalizedString("No missed calls", comment: "No missed calls")
        }
        let cell = dequeueReusableCell(cellIdentifier: .errorText, for: indexPath)
        cell.textLabel?.text = noRecents
        return cell
    }

    fileprivate func recentCell(indexPath: IndexPath) -> UITableViewCell {
        let cell = dequeueReusableCell(cellIdentifier: .recentCall, for: indexPath) as! RecentTableViewCell
        let recent = fetchedResultController.object(at: indexPath)
        cell.inbound = recent.inbound!.boolValue
        cell.name = recent.displayName
        cell.subtitle = recent.phoneType
        cell.date = recent.callDate
        cell.answered = recent.duration != 0 && recent.inbound!.boolValue
        return cell
    }
}
