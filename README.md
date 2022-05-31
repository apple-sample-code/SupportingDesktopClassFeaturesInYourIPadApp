# Supporting desktop-class features in your iPad app

Enhance your iPad app by adding desktop-class features and document support.

## Overview

This sample app shows how to build an iPad app with desktop-class features, 
focusing on rich document-editing capabilities including 
a title menu with custom actions, document renaming, Find and Replace, 
and more.
The app is a markup document editor that allows creating, editing, previewing, 
and saving documents.

- Note: This sample code project is associated with WWDC22 sessions: [10069: Meet desktop class iPad](https://developer.apple.com/wwdc22/10069/), [10070: Build a desktop class iPad app](https://developer.apple.com/wwdc22/10070/), and [10076: Bring your iOS app to the Mac](https://developer.apple.com/wwdc22/10076/).

## Choose the appropriate navigation style

Because the app allows focused viewing and editing of individual documents, 
it uses the 
[`UINavigationItem.ItemStyle.editor`](https://developer.apple.com/documentation/uikit/uinavigationitem/itemstyle/editor)
navigation style.
This navigation style moves the navigation item's title to the leading edge 
and opens up space in the center of the bar for common document actions.
To choose the navigation style, the editor view controller assigns the 
navigation item's
[`style`](https://developer.apple.com/documentation/uikit/uinavigationitem/3987969-style) 
property. 

``` swift
// Adopt the editor navigation style for the navigation item.
navigationItem.style = .editor
```
[View in Source](x-source-tag://EditorViewController)

## Add center items for quick access to common actions

Center item groups are groups of controls that appear in the 
navigation bar to provide quick access to the app’s most important capabilities. 
A person can customize the navigation bar's center items by moving, removing, 
or adding certain groups. 
To enable user customization, the app assigns a string to the 
navigation item's 
[`customizationIdentifier`](https://developer.apple.com/documentation/uikit/uinavigationitem/3987968-customizationidentifier)
property.

``` swift
// Set a customizationIdentifier and add center item groups.
navigationItem.customizationIdentifier = "editorViewCustomization"
```
[View in Source](x-source-tag://EditorViewController)

The editor view controller configures center items and assigns them to 
the navigation item's 
[`centerItemGroups`](https://developer.apple.com/documentation/uikit/uinavigationitem/3987967-centeritemgroups)
property in `configureCenterItemGroups()`.
The editor view controller creates one fixed group that people can't move 
or remove from the navigation bar for the Sync Scrolling item using
[`creatingFixedGroup()`](https://developer.apple.com/documentation/uikit/uibarbuttonitem/3987945-creatingfixedgroup).

``` swift
UIBarButtonItem(primaryAction: UIAction(title: "Sync Scrolling", image: syncScrollingImage) { [unowned self] action in
    syncScrolling.toggle()
    if let barButtonItem = action.sender as? UIBarButtonItem {
        barButtonItem.image = syncScrollingImage
    }
}).creatingFixedGroup(),
```
[View in Source](x-source-tag://ConfigureCenterItems) 

Other center item groups are optional, which means people can customize their
placement in the navigation bar. Optional groups that have 
`isInDefaultCustomization` set to `false` don't appear in the navigation bar by
default. They appear in the customization popover that a person can access
by choosing the customization option in the overflow menu.

``` swift
UIBarButtonItem(primaryAction: UIAction(title: "Strikethrough", image: UIImage(systemName: "strikethrough")) { [unowned self] _ in
    insertTag(.strikethrough)
}).creatingOptionalGroup(customizationIdentifier: "strikethrough", isInDefaultCustomization: false),
```
[View in Source](x-source-tag://ConfigureCenterItems)

## Add a title menu with system and custom actions

A title menu appears when a person taps the navigation item’s title.
This menu can surface actions that are relevant to the current document.
To configure a title menu,
the editor view controller assigns a closure to the navigation item’s 
[`titleMenuProvider`](https://developer.apple.com/documentation/uikit/uinavigationitem/3967523-titlemenuprovider)
property.

``` swift
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
```
[View in Source](x-source-tag://TitleMenu)

The closure returns a menu that combines the suggested system actions and 
custom actions.
The first set of actions in the menu are the `suggested` actions that the 
system passes in to the closure, including Move and Duplicate.
The next set of actions are the `custom` actions that the app defines: 
exporting the document to HTML and PDF.

## Configure a document header

A document header displays helpful information about the current document, 
such as its title, file type, and size.
It also provides a place from which to share or drag and drop the document.
To display a document header at the top of the title menu, 
the editor view controller assigns a 
[`UIDocumentProperties`](https://developer.apple.com/documentation/uikit/uidocumentproperties)
object to the navigation item’s 
[`documentProperties`](https://developer.apple.com/documentation/uikit/uinavigationitem/3967521-documentproperties)
property. 

``` swift
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
```
[View in Source](x-source-tag://DocumentHeader)

## Implement document renaming

[`UINavigationItem`](https://developer.apple.com/documentation/uikit/uinavigationitem)
provides support for quickly changing the item's title using a system UI. 
To enable the system rename UI, the editor view controller adopts the 
`UINavigationItemRenameDelegate`
protocol and assigns itself as the navigation item's rename delegate using the
[`renameDelegate`](https://developer.apple.com/documentation/uikit/uinavigationitem/3967522-renamedelegate)
property.

``` swift
// Enable the bar's built-in rename UI by setting the navigation item's
// `renameDelegate`.
navigationItem.renameDelegate = self
```
[View in Source](x-source-tag://EditorViewController)

The Rename action appears in the title menu as one of the system-suggested 
actions. When a person taps the Rename action, the system shows an inline 
text field UI for changing the navigation item’s title.
After a person completes renaming the item in the UI, the system calls 
[`navigationItem(_:didEndRenamingWith:)`](https://developer.apple.com/documentation/uikit/uinavigationitemrenamedelegate/3967525-navigationitem)
to perform the corresponding naming updates in the data model.

## Enable the system Find and Replace experience

The editor view supports editing the content of the document.
Because the editor view is a subclass of 
[`UITextView`](https://developer.apple.com/documentation/uikit/uitextview), 
enabling the system 
Find and Replace experience takes one line of code.

``` swift
// Enable Find and Replace in editor text view and register as its
// delegate.
editorTextView.isFindInteractionEnabled = true
```
[View in Source](x-source-tag://EditorViewController)

Setting the 
[`isFindInteractionEnabled`](https://developer.apple.com/documentation/uikit/uitextview/3975939-isfindinteractionenabled) 
property enables using standard keyboard shortcuts to find text in a document 
and quickly replace it using the system-provided Find panel.

## Enhance multiple-item selection

The outline view is a collection view that serves as a table of 
contents for the document, allowing for quick navigation 
or taking actions on the top-level tags in the document. 
This view supports an enhanced multiple-selection experience when a 
person interacts with the app using a keyboard and pointer.
The outline view enables lightweight multiple selection of the tags 
without placing the collection view into editing mode by setting 
[`allowsMultipleSelection`](https://developer.apple.com/documentation/uikit/uicollectionview/1618024-allowsmultipleselection),
[`allowsFocus`](https://developer.apple.com/documentation/uikit/uicollectionview/3795590-allowsfocus),
and 
[`selectionFollowsFocus`](https://developer.apple.com/documentation/uikit/uicollectionview/3573920-selectionfollowsfocus)
to `true`.

``` swift
// Enable multiple selection.
collectionView.allowsMultipleSelection = true

// Enable keyboard focus.
collectionView.allowsFocus = true

// Allow keyboard focus to drive selection.
collectionView.selectionFollowsFocus = true
```
[View in Source](x-source-tag://OutlineViewController)

A person can use the keyboard and pointer to select tags, and perform a 
secondary click to open a context menu with relevant actions.
The outline view presents a specialized context menu according to the number
of tags in the selection by implementing
[`collectionView(_:contextMenuConfigurationForItemsAt:point:)`](https://developer.apple.com/documentation/uikit/uicollectionviewdelegate/4002186-collectionview)
to return different configurations when the selection contains one or many tags.

``` swift
if indexPaths.count > 1 {
    // Action titles for a multiple-item menu.
    hideTitle = "Hide Selected"
    deleteTitle = "Delete Selected"
} else {
    // Action titles for a single-item menu.
    hideTitle = "Hide"
    deleteTitle = "Delete"
}
```
[View in Source](x-source-tag://ContextMenus)
    
## Perform a primary action when tapping a single item

In addition to performing a secondary click on a tag in the outline view,
a person can tap a single tag to scroll to its 
corresponding location in the editor view.
To distinguish the explicit user action of tapping one tag to navigate to that 
location in the document from selecting multiple tags, 
the outline view implements 
[`collectionView(_:performPrimaryActionForItemAt:)`](https://developer.apple.com/documentation/uikit/uicollectionviewdelegate/3975794-collectionview).
The system calls this method when a person taps a single tag without extending 
a multiple selection of tags.

``` swift
func collectionView(_ collectionView: UICollectionView, performPrimaryActionForItemAt indexPath: IndexPath) {
    // Get the element at the indexPath.
    if let element = dataSource.itemIdentifier(for: indexPath) {
        delegate?.outline(self, didChoose: element)
    }

    // Wait a short amount of time before deselecting the cell for visual clarity.
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
        collectionView.deselectItem(at: indexPath, animated: true)
    }
}
```
[View in Source](x-source-tag://PrimaryAction)
