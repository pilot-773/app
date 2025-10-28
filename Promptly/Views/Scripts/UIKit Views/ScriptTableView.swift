//
//  ScriptTableView.swift
//  Promptly
//
//  Created by Sasha Bagrov on 27/10/2025.
//

import Foundation
import UIKit
import SwiftUI

struct ScriptTableView: UIViewRepresentable {
    let lineGroups: [LineGroup]
    
    // Edit mode properties
    let isEditing: Bool
    let selectedLines: Set<UUID>
    let editingLineId: UUID?
    let isSelectingForSection: Bool
    @Binding var editingText: String
    
    // Edit mode callbacks
    let onToggleSelection: ((ScriptLine) -> Void)?
    let onStartTextEdit: ((ScriptLine) -> Void)?
    let onFinishTextEdit: ((String) -> Void)?
    let onInsertAfter: ((ScriptLine) -> Void)?
    let onEditFlags: ((ScriptLine) -> Void)?
    let onSectionTap: ((ScriptSection) -> Void)?
    
    // Reading mode properties
    let selectedLine: ScriptLine?
    
    // Reading mode callbacks
    let onElementTap: ((LineElement, ScriptLine) -> Void)?
    let onLineTap: ((ScriptLine) -> Void)?
    let onEditComplete: ((ScriptLine, String) -> Void)?
    let onCueDelete: ((Cue) -> Void)?
    let onCueEdit: ((Cue) -> Void)?
    
    private let mode: TableMode
    
    enum TableMode {
        case editing, reading
    }
    
    // MARK: - Dual Initialisers
    
    // Edit mode initialiser (unchanged)
    init(
        lineGroups: [LineGroup],
        isEditing: Bool,
        selectedLines: Set<UUID>,
        editingLineId: UUID?,
        isSelectingForSection: Bool,
        editingText: Binding<String>,
        onToggleSelection: @escaping (ScriptLine) -> Void,
        onStartTextEdit: @escaping (ScriptLine) -> Void,
        onFinishTextEdit: @escaping (String) -> Void,
        onInsertAfter: @escaping (ScriptLine) -> Void,
        onEditFlags: @escaping (ScriptLine) -> Void,
        onSectionTap: @escaping (ScriptSection) -> Void
    ) {
        self.lineGroups = lineGroups
        self.isEditing = isEditing
        self.selectedLines = selectedLines
        self.editingLineId = editingLineId
        self.isSelectingForSection = isSelectingForSection
        self._editingText = editingText
        self.onToggleSelection = onToggleSelection
        self.onStartTextEdit = onStartTextEdit
        self.onFinishTextEdit = onFinishTextEdit
        self.onInsertAfter = onInsertAfter
        self.onEditFlags = onEditFlags
        self.onSectionTap = onSectionTap
        
        // Reading mode defaults
        self.selectedLine = nil
        self.onElementTap = nil
        self.onLineTap = nil
        self.onEditComplete = nil
        self.onCueDelete = nil
        self.onCueEdit = nil
        
        self.mode = .editing
    }
    
    // Reading mode initialiser
    init(
        lineGroups: [LineGroup],
        selectedLine: ScriptLine?,
        editingLineId: UUID?,
        editingText: Binding<String>,
        onElementTap: @escaping (LineElement, ScriptLine) -> Void,
        onLineTap: @escaping (ScriptLine) -> Void,
        onEditComplete: @escaping (ScriptLine, String) -> Void,
        onCueDelete: @escaping (Cue) -> Void,
        onCueEdit: @escaping (Cue) -> Void,
        onSectionTap: @escaping (ScriptSection) -> Void
    ) {
        self.lineGroups = lineGroups
        self.selectedLine = selectedLine
        self.editingLineId = editingLineId
        self._editingText = editingText
        self.onElementTap = onElementTap
        self.onLineTap = onLineTap
        self.onEditComplete = onEditComplete
        self.onCueDelete = onCueDelete
        self.onCueEdit = onCueEdit
        self.onSectionTap = onSectionTap
        
        // Edit mode defaults
        self.isEditing = false
        self.selectedLines = []
        self.isSelectingForSection = false
        self.onToggleSelection = nil
        self.onStartTextEdit = nil
        self.onFinishTextEdit = nil
        self.onInsertAfter = nil
        self.onEditFlags = nil
        
        self.mode = .reading
    }
    
    func makeUIView(context: Context) -> UITableView {
        let tableView = UITableView()
        tableView.delegate = context.coordinator
        tableView.dataSource = context.coordinator
        tableView.separatorStyle = .none
        tableView.backgroundColor = UIColor.systemGroupedBackground
        tableView.showsVerticalScrollIndicator = true
        tableView.contentInset = UIEdgeInsets(top: 16, left: 0, bottom: 16, right: 0)
        
        // Register cells for both modes
        tableView.register(HostingLineCell.self, forCellReuseIdentifier: "LineCell")
        tableView.register(HostingReadingLineCell.self, forCellReuseIdentifier: "ReadingLineCell")
        tableView.register(HostingSectionCell.self, forCellReuseIdentifier: "SectionCell")
        
        return tableView
    }
    
    func updateUIView(_ uiView: UITableView, context: Context) {
        context.coordinator.parent = self
        uiView.reloadData()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITableViewDataSource, UITableViewDelegate {
        var parent: ScriptTableView
        
        init(_ parent: ScriptTableView) {
            self.parent = parent
        }
        
        private var flattenedItems: [(type: ItemType, group: LineGroup, line: ScriptLine?)] {
            var items: [(ItemType, LineGroup, ScriptLine?)] = []
            
            for group in parent.lineGroups {
                if let section = group.section {
                    items.append((.section, group, nil))
                }
                for line in group.lines {
                    items.append((.line, group, line))
                }
            }
            return items
        }
        
        func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            return flattenedItems.count
        }
        
        func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            let item = flattenedItems[indexPath.row]
            
            switch item.type {
            case .section:
                let cell = tableView.dequeueReusableCell(withIdentifier: "SectionCell", for: indexPath) as! HostingSectionCell
                cell.configure(with: item.group.section!, onTap: parent.onSectionTap!)
                return cell
                
            case .line:
                switch parent.mode {
                case .editing:
                    let cell = tableView.dequeueReusableCell(withIdentifier: "LineCell", for: indexPath) as! HostingLineCell
                    cell.configure(
                        line: item.line!,
                        isEditing: parent.isEditing,
                        isSelected: parent.selectedLines.contains(item.line!.id),
                        isEditingText: parent.editingLineId == item.line!.id,
                        isSelectingForSection: parent.isSelectingForSection,
                        editingText: parent.editingText,
                        onToggleSelection: parent.onToggleSelection!,
                        onStartTextEdit: parent.onStartTextEdit!,
                        onFinishTextEdit: parent.onFinishTextEdit!,
                        onInsertAfter: parent.onInsertAfter!,
                        onEditFlags: parent.onEditFlags!
                    )
                    return cell
                    
                case .reading:
                    let cell = tableView.dequeueReusableCell(withIdentifier: "ReadingLineCell", for: indexPath) as! HostingReadingLineCell
                    cell.configure(
                        line: item.line!,
                        isSelected: parent.selectedLine?.id == item.line!.id,
                        isEditing: parent.editingLineId == item.line!.id,
                        editingText: parent.editingText,
                        onElementTap: { element in
                            self.parent.onElementTap?(element, item.line!) //
                        },
                        onLineTap: {
                            self.parent.onLineTap?(item.line!) //
                        },
                        onEditComplete: { newText in
                            self.parent.onEditComplete?(item.line!, newText) //
                        },
                        onCueDelete: parent.onCueDelete!,
                        onCueEdit: parent.onCueEdit!
                    )
                    return cell
                }
            }
        }
        
        func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
            let item = flattenedItems[indexPath.row]
            return item.type == .section ? 80 : 60
        }
        
        func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
            return UITableView.automaticDimension
        }
    }
    
    enum ItemType {
        case section, line
    }
}

// UITableViewCell that hosts SwiftUI line content
class HostingLineCell: UITableViewCell {
    private var hostingController: UIHostingController<AnyView>?
    
    override func prepareForReuse() {
        super.prepareForReuse()
        // Clean up when cell is reused
        hostingController?.view.removeFromSuperview()
        hostingController = nil
    }
    
    func configure(
        line: ScriptLine,
        isEditing: Bool,
        isSelected: Bool,
        isEditingText: Bool,
        isSelectingForSection: Bool,
        editingText: String,
        onToggleSelection: @escaping (ScriptLine) -> Void,
        onStartTextEdit: @escaping (ScriptLine) -> Void,
        onFinishTextEdit: @escaping (String) -> Void,
        onInsertAfter: @escaping (ScriptLine) -> Void,
        onEditFlags: @escaping (ScriptLine) -> Void
    ) {
        // Create binding for editingText
        let editingTextBinding = Binding<String>(
            get: { editingText },
            set: { _ in } // Handle in the callbacks
        )
        
        let swiftUIView = AnyView(
            EditableScriptLineView(
                line: line,
                isEditing: isEditing,
                isSelected: isSelected,
                isEditingText: isEditingText,
                isSelectingForSection: isSelectingForSection,
                editingText: editingTextBinding,
                onToggleSelection: onToggleSelection,
                onStartTextEdit: onStartTextEdit,
                onFinishTextEdit: onFinishTextEdit,
                onInsertAfter: onInsertAfter,
                onEditFlags: onEditFlags
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        )
        
        if let hostingController = hostingController {
            hostingController.rootView = swiftUIView
        } else {
            hostingController = UIHostingController(rootView: swiftUIView)
            hostingController!.view.backgroundColor = .clear
            hostingController!.view.translatesAutoresizingMaskIntoConstraints = false
            
            contentView.addSubview(hostingController!.view)
            NSLayoutConstraint.activate([
                hostingController!.view.topAnchor.constraint(equalTo: contentView.topAnchor),
                hostingController!.view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                hostingController!.view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                hostingController!.view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
            ])
        }
        
        // Ensure proper selection state
        selectionStyle = .none
        backgroundColor = .clear
    }
}

// UITableViewCell that hosts SwiftUI section content
class HostingSectionCell: UITableViewCell {
    private var hostingController: UIHostingController<AnyView>?
    
    override func prepareForReuse() {
        super.prepareForReuse()
        // Clean up when cell is reused
        hostingController?.view.removeFromSuperview()
        hostingController = nil
    }
    
    func configure(with section: ScriptSection, onTap: @escaping (ScriptSection) -> Void) {
        let swiftUIView = AnyView(
            Button(action: { onTap(section) }) {
                SectionHeaderView(section: section)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 16)
            .padding(.top, 8)
        )
        
        if let hostingController = hostingController {
            hostingController.rootView = swiftUIView
        } else {
            hostingController = UIHostingController(rootView: swiftUIView)
            hostingController!.view.backgroundColor = .clear
            hostingController!.view.translatesAutoresizingMaskIntoConstraints = false
            
            contentView.addSubview(hostingController!.view)
            NSLayoutConstraint.activate([
                hostingController!.view.topAnchor.constraint(equalTo: contentView.topAnchor),
                hostingController!.view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                hostingController!.view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                hostingController!.view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
            ])
        }
        
        // Ensure proper selection state
        selectionStyle = .none
        backgroundColor = .clear
    }
}


class HostingReadingLineCell: UITableViewCell {
    private var hostingController: UIHostingController<AnyView>?
    
    override func prepareForReuse() {
        super.prepareForReuse()
        hostingController?.view.removeFromSuperview()
        hostingController = nil
    }
    
    func configure(
        line: ScriptLine,
        isSelected: Bool,
        isEditing: Bool,
        editingText: String,
        onElementTap: @escaping (LineElement) -> Void,
        onLineTap: @escaping () -> Void,
        onEditComplete: @escaping (String) -> Void,
        onCueDelete: @escaping (Cue) -> Void,
        onCueEdit: @escaping (Cue) -> Void
    ) {
        let editingTextBinding = Binding<String>(
            get: { editingText },
            set: { _ in }
        )
        
        let swiftUIView = AnyView(
            ScriptLineView(
                line: line,
                isSelected: isSelected,
                isEditing: isEditing,
                editingText: editingTextBinding,
                onElementTap: onElementTap,
                onLineTap: onLineTap,
                onEditComplete: onEditComplete,
                onCueDelete: onCueDelete,
                onCueEdit: onCueEdit
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        )
        
        if let hostingController = hostingController {
            hostingController.rootView = swiftUIView
        } else {
            hostingController = UIHostingController(rootView: swiftUIView)
            hostingController!.view.backgroundColor = .clear
            hostingController!.view.translatesAutoresizingMaskIntoConstraints = false
            
            contentView.addSubview(hostingController!.view)
            NSLayoutConstraint.activate([
                hostingController!.view.topAnchor.constraint(equalTo: contentView.topAnchor),
                hostingController!.view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                hostingController!.view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                hostingController!.view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
            ])
        }
        
        selectionStyle = .none
        backgroundColor = .clear
    }
}
