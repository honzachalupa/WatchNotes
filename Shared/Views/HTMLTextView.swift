import SwiftUI

struct HTMLTextView: View {
    let htmlContent: String?
    @State private var components: [HTMLComponent] = []
    
    init(htmlContent: String?) {
        print("[HTMLTextView] init with content: \(String(describing: htmlContent?.prefix(100)))")
        self.htmlContent = htmlContent
    }
    
    private struct HTMLComponent: Identifiable, Hashable {
        let id = UUID()
        let type: ComponentType
        let text: String
        
        enum ComponentType: Hashable {
            case header1
            case header2
            case header3
            case paragraph
            case listItem
            case bold
            case link
        }
    }
    
    var body: some View {
        if let content = htmlContent {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(components) { component in
                    switch component.type {
                        case .header1:
                            Text(component.text)
                                .font(.title)
                                .fontWeight(.bold)
                                .padding(.vertical, 8)
                        case .header2:
                            Text(component.text)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .padding(.vertical, 6)
                        case .header3:
                            Text(component.text)
                                .font(.title3)
                                .fontWeight(.medium)
                                .padding(.vertical, 4)
                        case .bold:
                            Text(component.text)
                                .fontWeight(.bold)
                                .padding(.vertical, 2)
                        case .paragraph:
                            Text(component.text)
                                .font(.body)
                                .padding(.vertical, 2)
                        case .listItem:
                            HStack(alignment: .top, spacing: 8) {
                                Text("•")
                                    .frame(width: 20, alignment: .trailing)
                                Text(component.text)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.leading, 20)
                        case .link:
                            Link(component.text, destination: URL(string: component.text) ?? URL(string: "about:blank")!)
                                .foregroundColor(.blue)
                    }
                }
            }
            .onAppear {
                parseHTML(content)
            }
            .onChange(of: content) {
                parseHTML(content)
            }
        } else {
            Text("No content")
        }
    }
    
    private func parseHTML(_ html: String) {
        print("[HTMLTextView] ParseHTML called with length: \(html.count)")
        
        // Clean up the content first
        var content = html
            .replacingOccurrences(of: "<div>", with: "")
            .replacingOccurrences(of: "</div>", with: "")
            .replacingOccurrences(of: "<br>", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Convert Apple's dash lists to standard lists
        content = content.replacingOccurrences(of: "<ul class=\"Apple-dash-list\">", with: "<ul>")
        
        // Split content by newlines to handle each line separately
        let lines = content.components(separatedBy: .newlines)
        var newComponents: [HTMLComponent] = []
        var currentIndentLevel = 0
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            
            // Calculate indent level for nested lists
            if trimmed.contains("<ul>") {
                currentIndentLevel += 1
                continue
            } else if trimmed.contains("</ul>") {
                currentIndentLevel -= 1
                continue
            }
            
            // Handle headers
            if trimmed.contains("<h1>") {
                if let text = extract(from: trimmed, tag: "h1") {
                    newComponents.append(.init(type: .header1, text: text))
                }
            }
            // Handle list items with proper indentation
            else if trimmed.contains("<li>") {
                if let text = extract(from: trimmed, tag: "li") {
                    let indentedText = String(repeating: "   ", count: currentIndentLevel) + text

                    newComponents.append(.init(type: .listItem, text: indentedText))
                }
            }
            // Handle plain text
            else if !trimmed.contains("</") && !trimmed.contains("<") {
                let text = clean(trimmed)
                if !text.isEmpty {
                    newComponents.append(.init(type: .paragraph, text: text))
                }
            }
        }
        
        components = newComponents
    }
    
    private func extract(from html: String, tag: String) -> String? {
        print("[HTMLTextView] Extracting \(tag) from: \(html)")

        let pattern = "<\(tag)[^>]*>(.*?)</\(tag)>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            print("[HTMLTextView] Failed to create regex for tag: \(tag)")
            return nil
        }
        
        if let match = regex.firstMatch(in: html, options: [], range: NSRange(html.startIndex..., in: html)),
           let range = Range(match.range(at: 1), in: html) {
            return clean(String(html[range]))
        }
        
        return nil
    }
    
    private func clean(_ text: String) -> String {
        print("[HTMLTextView] Cleaning text: \(text)")
        // Remove HTML tags
        var cleaned = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        
        // Handle HTML entities
        cleaned = cleaned
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "<", with: "")
            .replacingOccurrences(of: "\t", with: "    ")
        
        // Clean whitespace
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    

}

private extension String {
    func contains(class className: String) -> Bool {
        self.contains("class=\"") && self.contains(className)
    }
}
