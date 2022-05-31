/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The view controller that configures and manages operations in the
 main editor view.
*/

import UIKit

protocol EditorViewControllerDelegate: AnyObject {
    func editor(_ editorViewController: EditorViewController, didParse document: ParsedDocument)
}
class EditorViewController: UIViewController,
        UINavigationItemRenameDelegate,
        UITextViewDelegate,
        UIDocumentPickerDelegate,
        UIImagePickerControllerDelegate,
        UINavigationControllerDelegate {

    let editorTextView = EditorView()
    let previewView = PreviewView()
    let parser = Parser()
    let updateQueue = OperationQueue()
    let document: MarkdownDocument

    var scrollSyncSource: UIScrollView?
    
    weak var delegate: EditorViewControllerDelegate?
    weak var documentBrowser: DocumentBrowserViewController?

    var isPickingImageFromFile = true
    
    var splitView: SplitView {
        view as! SplitView
    }
    
    var syncScrolling = UserDefaults.standard.bool(forKey: "LastSyncScrollingValue") {
        didSet {
            UserDefaults.standard.set(syncScrolling, forKey: "LastSyncScrollingValue")
            syncScrollPositionIfNecessary()
        }
    }
    
    init(document: MarkdownDocument) {
        self.document = document
        super.init(nibName: nil, bundle: nil)
        
        self.document.didUpdateHandler = { document, adjustedSelectionRange in
            self.editorTextView.text = document.text
            
            // Adjust selected range.
            if let newSelectionRange = adjustedSelectionRange {
                self.editorTextView.selectedRange = newSelectionRange
            }
            
            // Manually trigger a parser update, since textViewDidChange(_:) won't be called.
            self.updatePreview()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: UIViewController Overrides
    
    override func loadView() {
        view = SplitView()
        view.backgroundColor = UIColor(named: "EditorBackgroundColor")
    }
    
    /// - Tag: EditorViewController
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Adopt the editor navigation style for the navigation item.
        navigationItem.style = .editor
        
        // Set a custom back action that dismisses the editor and returns
        // to the document browser.
        navigationItem.backAction = UIAction(title: "Documents") { [unowned self] _ in
            dismiss(animated: true)
        }
        
        // Enable the bar's built-in rename UI by setting the navigation item's
        // `renameDelegate`.
        navigationItem.renameDelegate = self
        
        // Set a customizationIdentifier and add center item groups.
        navigationItem.customizationIdentifier = "editorViewCustomization"
        configureCenterItemGroups()
        
        navigationItem.rightBarButtonItem = splitView.previewVisibilityBarButton

        // Enable Find and Replace in editor text view and register as its
        // delegate.
        editorTextView.isFindInteractionEnabled = true
        editorTextView.delegate = self
        
        splitView.panels = [ editorTextView, previewView ]
        previewView.webView.scrollView.delegate = self
    }
    
    override func viewLayoutMarginsDidChange() {
        super.viewLayoutMarginsDidChange()

        var layoutMargins = view.layoutMargins
        layoutMargins.top = layoutMargins.left
        layoutMargins.bottom = 100
        editorTextView.textContainerInset = layoutMargins
    }
    
    // MARK: UIScrollViewDelegate

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        syncScrollPositionIfNecessary()
    }
    
    func scrollViewShouldScrollToTop(_ scrollView: UIScrollView) -> Bool {
        scrollSyncSource = scrollView
        return true
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        scrollSyncSource = scrollView
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        scrollSyncSource = nil
    }
    
    func scrollViewDidChangeAdjustedContentInset(_ scrollView: UIScrollView) {
        scrollView.contentOffset = CGPoint(x: 0, y: -scrollView.adjustedContentInset.top)
    }
    
    // MARK: UITextViewDelegate
    
    func textView(_ textView: UITextView, editMenuForTextIn range: NSRange, suggestedActions: [UIMenuElement]) -> UIMenu? {
        // Insert custom actions into the text view's edit menu.
        if textView.selectedRange.length > 0 {
            return UIMenu(children: suggestedActions + [ hideSelectedCommand ])
        }
        
        return nil
    }
    
    func textViewDidChange(_ textView: UITextView) {
        updatePreview()
    }
    
    // MARK: UINavigationItemRenameDelegate
    
    /// The system calls this method when a rename interaction in the bar ends.
    /// Perform the actual rename here.
    func navigationItem(_ navigationItem: UINavigationItem, didEndRenamingWith title: String) {
        documentBrowser?.renameDocument(at: document.fileURL, proposedName: title) { [unowned self] url, error in
            // The rename interaction automatically updates the navigation item's title.
            // If renaming fails for any reason, restore the title to the document's old name.
            if error != nil {
                self.navigationItem.title = self.document.localizedName
            }
        }
    }
    
    // MARK: Title Menu Actions
    
    override func duplicate(_ sender: Any?) {
        let picker = UIDocumentPickerViewController(forExporting: [document.fileURL], asCopy: true)
        picker.delegate = self
        present(picker, animated: true)
    }

    override func move(_ sender: Any?) {
        let picker = UIDocumentPickerViewController(forExporting: [document.fileURL])
        picker.delegate = self
        present(picker, animated: true)
    }
    
    // MARK: Center Items
        
    /// Configures an array of `UIBarButtonItemGroup` objects to display in the center of the top bar.
    /// - Tag: ConfigureCenterItems
    private func configureCenterItemGroups() {
        let sliderItem = UIBarButtonItem(customView: editorTextView.textSizeSlider)
        sliderItem.title = "Text Size"
        let sliderGroup = sliderItem.creatingOptionalGroup(customizationIdentifier: "textSlider")
        sliderGroup.menuRepresentation = editorTextView.textSizeMenu()

        let formatItems = [
            UIBarButtonItem(primaryAction: UIAction(title: "Bold", image: UIImage(systemName: "bold")) { [unowned self] action in
                toggleBoldface(action.sender)
            }),
            UIBarButtonItem(primaryAction: UIAction(title: "Italicize", image: UIImage(systemName: "italic")) { [unowned self] action in
                toggleItalics(action.sender)
            }),
            UIBarButtonItem(primaryAction: UIAction(title: "Underline", image: UIImage(systemName: "underline")) { [unowned self] action in
                toggleUnderline(action.sender)
            })
        ]
        
        let headingItems = [
            UIBarButtonItem(primaryAction: UIAction(title: "H1") { [unowned self] _ in
                insertTag(.heading(1))
            }),
            UIBarButtonItem(primaryAction: UIAction(title: "H2") { [unowned self] _ in
                insertTag(.heading(2))
            }),
            UIBarButtonItem(primaryAction: UIAction(title: "H3") { [unowned self] _ in
                insertTag(.heading(3))
            })
        ]
        
        navigationItem.centerItemGroups = [
            UIBarButtonItem(primaryAction: UIAction(title: "Sync Scrolling", image: syncScrollingImage) { [unowned self] action in
                syncScrolling.toggle()
                if let barButtonItem = action.sender as? UIBarButtonItem {
                    barButtonItem.image = syncScrollingImage
                }
            }).creatingFixedGroup(),
            
            UIBarButtonItem(primaryAction: UIAction(title: "Add Link", image: UIImage(systemName: "link")) { [unowned self] _ in
                insertTag(.link)
            }).creatingOptionalGroup(customizationIdentifier: "addLink"),
            
            UIBarButtonItem(title: "Insert Image", image: UIImage(systemName: "photo"), menu: UIMenu(title: "Insert Image", children: [
                UIAction(title: "From Photo Library", image: UIImage(systemName: "photo.on.rectangle")) { [unowned self] _ in
                    let picker = UIImagePickerController()
                    picker.delegate = self
                    present(picker, animated: true)
                },
                UIAction(title: "From File", image: UIImage(systemName: "folder")) { [unowned self] _ in
                    let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.image], asCopy: true)
                    picker.delegate = self
                    isPickingImageFromFile = true
                    present(picker, animated: true)
                },
                UIAction(title: "Blank Image Tag", image: UIImage(systemName: "tag")) { [unowned self] _ in
                    insertTag(.image)
                }
            ])).creatingOptionalGroup(customizationIdentifier: "addImage"),
            
            UIBarButtonItem(primaryAction: UIAction(
                title: "Code",
                image: UIImage(systemName: "chevron.left.forwardslash.chevron.right")) { [unowned self] _ in
                insertTag(.codeBlock())
            }).creatingOptionalGroup(customizationIdentifier: "codeBlock"),
            
            sliderGroup,
                        
            .optionalGroup(customizationIdentifier: "format",
                           isInDefaultCustomization: false,
                           representativeItem: UIBarButtonItem(title: "Format", image: UIImage(systemName: "bold.italic.underline")),
                           items: formatItems),
            
            UIBarButtonItem(primaryAction: UIAction(title: "Strikethrough", image: UIImage(systemName: "strikethrough")) { [unowned self] _ in
                insertTag(.strikethrough)
            }).creatingOptionalGroup(customizationIdentifier: "strikethrough", isInDefaultCustomization: false),
            
            UIBarButtonItem(primaryAction: UIAction(title: "Quote", image: UIImage(systemName: "text.quote")) { [unowned self] _ in
                insertTag(.blockQuote)
            }).creatingOptionalGroup(customizationIdentifier: "blockQuote", isInDefaultCustomization: false),
            
            .optionalGroup(customizationIdentifier: "headings",
                           isInDefaultCustomization: false,
                           representativeItem: UIBarButtonItem(title: "Heading", image: UIImage(systemName: "h.square")),
                           items: headingItems)
        ]
    }
    
    // MARK: Document Management
    /// - Tag: TitleMenu
    func didOpenDocument() {
        document.undoManager = editorTextView.undoManager
        document.willSaveHandler = {
            self.editorTextView.text
        }

        editorTextView.text = document.text
        updatePreview()
        
        updateDocumentProperties()
        navigationItem.titleMenuProvider = { suggested in
            let custom = [
                UIMenu(title: "Export…", image: UIImage(systemName: "arrow.up.forward.square"), children: [
                    UIAction(title: "HTML", image: UIImage(systemName: "safari")) { [unowned self] _ in
                        previewView.exportAsWebArchive(named: document.localizedName, presenter: self)
                    },
                    UIAction(title: "PDF", image: UIImage(systemName: "doc.richtext")) { [unowned self] _ in
                        previewView.exportAsPDF(named: document.localizedName, presenter: self)
                    }
                ])
            ]
            return UIMenu(children: suggested + custom)
        }
    }
    
    /// - Tag: DocumentHeader
    private func updateDocumentProperties() {
        let documentProperties = UIDocumentProperties(url: document.fileURL)
        if let itemProvider = NSItemProvider(contentsOf: document.fileURL) {
            documentProperties.dragItemsProvider = { _ in
                [UIDragItem(itemProvider: itemProvider)]
            }
            documentProperties.activityViewControllerProvider = {
                UIActivityViewController(activityItems: [itemProvider], applicationActivities: nil)
            }
        }
        
        navigationItem.title = document.localizedName
        navigationItem.documentProperties = documentProperties
    }
    
    // MARK: UIDocumentPickerDelegate
    
    /// The app uses `UIDocumentPickerViewController` to move and duplicate documents.
    /// After the document selection operation is complete, the underlying `UIDocument` updates
    /// and the system calls this method.
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        if isPickingImageFromFile {
            // If isPickingImageFromFile is true, the picker was brought up to
            // select an image to insert.
            isPickingImageFromFile = false
            
            if let url = urls.first {
                insertImage(url)
            }
        } else {
            // Make sure the title menu's document properties header is up to date.
            updateDocumentProperties()
        }
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        isPickingImageFromFile = false
    }
    
    // MARK: UIImagePickerControllerDelegate
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        if let imageURL = info[.imageURL] as? URL {
            insertImage(imageURL)
        }
        
        dismiss(animated: true)
    }
    
    // MARK: Internal
    
    private func updatePreview() {
        if splitView.splitSize > 0, let markdownText = self.editorTextView.text {
            updateQueue.cancelAllOperations()
            updateQueue.addOperation {
                let parsedDocument = self.parser.parse(markdownText)
            
                self.document.parsedDocument = parsedDocument
                
                DispatchQueue.main.async {
                    self.previewView.webView.loadHTMLString(parsedDocument.html, baseURL: Bundle.main.resourceURL)
                    self.delegate?.editor(self, didParse: parsedDocument)
                    self.syncScrollPositionIfNecessary()
                }
            }
        }
    }
    
    private func syncScrollPositionIfNecessary() {
        if syncScrolling {
            let webScrollView = previewView.webView.scrollView
            
            var from: UIScrollView
            var destination: UIScrollView
            
            if let sourceScrollView = scrollSyncSource {
                from = sourceScrollView
            } else {
                from = editorTextView
            }
            
            if from == editorTextView {
                destination = webScrollView
            } else {
                destination = editorTextView
            }
                        
            let fromMaxYOffset = from.contentSize.height - (from.bounds.height - from.adjustedContentInset.top)
            let toMaxYOffset = destination.contentSize.height - (destination.bounds.height - destination.adjustedContentInset.top)
            
            let normalizedFromOffset = (from.contentOffset.y + from.adjustedContentInset.top) / fromMaxYOffset
            let expectedToOffset = CGPoint(x: 0, y: (normalizedFromOffset * toMaxYOffset) - destination.adjustedContentInset.top)

            if abs(expectedToOffset.y - destination.contentOffset.y) > (1.0 / traitCollection.displayScale) {
                destination.contentOffset = expectedToOffset
            }
        }
    }
    
    private var syncScrollingImage: UIImage? {
        UIImage(systemName: syncScrolling ? "align.vertical.center.fill" : "align.vertical.center")
    }
    
    private func insertTag(_ tag: MarkdownTag, onlyIfSelected: Bool = false) {
        let selectedRange = editorTextView.selectedRange
        if !onlyIfSelected || selectedRange.length > 0 {
            document.insertTag(tag, at: selectedRange)
        }
    }
    
    private func insertImage(_ url: URL) {
        let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let toURL = docsDir.appendingPathComponent(url.lastPathComponent)
        
        try? FileManager.default.copyItem(at: url, to: toURL)
        
        document.insertTag(.image, with: url.lastPathComponent, at: editorTextView.selectedRange.location)
    }
    
    // MARK: Key Commands

    override var keyCommands: [UIKeyCommand]? {
        return [
            hideSelectedCommand,
            UIKeyCommand(action: #selector(addLink), input: "k", modifierFlags: .command)
        ]
    }
    
    private var hideSelectedCommand: UIKeyCommand {
        UIKeyCommand(title: "Hide", image: UIImage(systemName: "eye.slash"), action: #selector(hideSelected), input: "/", modifierFlags: .command)
    }
    
    override func toggleBoldface(_ sender: Any?) {
        insertTag(.bold, onlyIfSelected: true)
    }
    
    override func toggleItalics(_ sender: Any?) {
        insertTag(.italicize, onlyIfSelected: true)
    }
    
    override func toggleUnderline(_ sender: Any?) {
        insertTag(.underline, onlyIfSelected: true)
    }
    
    @objc
    private func hideSelected(_ sender: Any?) {
        insertTag(.comment, onlyIfSelected: true)
    }
    
    @objc
    private func addLink(_ sender: Any?) {
        insertTag(.link)
    }
    
    // MARK: Outline Support
    
    func scroll(to outlineElement: OutlineElement) {
        // Create the `NSTextRange` from the text view.
        guard let startPosition = editorTextView.position(from: editorTextView.beginningOfDocument, offset: outlineElement.range.location),
              let endPosition = editorTextView.position(from: editorTextView.beginningOfDocument, offset: outlineElement.range.upperBound),
              let textRange = editorTextView.textRange(from: startPosition, to: endPosition)
        else { return }

        // Select the range.
        editorTextView.selectedRange = outlineElement.range

        // Get the y position for the top of the range.
        var yOffset = editorTextView.firstRect(for: textRange).minY

        // After scrolling, position the element at 1/4 of the visible height.
        let visibleHeight = editorTextView.visibleSize.height
        yOffset -= visibleHeight * 0.25

        // Constrain scrolling to avoid reaching a position the user can't
        // reach interactively.
        let maxOffset = editorTextView.contentSize.height - visibleHeight
        yOffset = max(min(yOffset, maxOffset), -editorTextView.adjustedContentInset.top)

        let contentOffset = CGPoint(x: editorTextView.contentOffset.x, y: yOffset)
        editorTextView.setContentOffset(contentOffset, animated: true)
    }
}
