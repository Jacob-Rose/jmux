#!/usr/bin/env python3
"""
Textual jmux - A modern TUI file manager with integrated file editing
"""

from pathlib import Path
from textual.app import App, ComposeResult
from textual.containers import Horizontal, Vertical, Container
from textual.widgets import DirectoryTree, Header, Footer, Static, Input, TextArea, Button, ListView, ListItem, Label
from textual.reactive import reactive
from textual.message import Message
from textual.screen import ModalScreen
from textual.command import Provider, Hit, Hits
from functools import partial
import subprocess
import os
import fnmatch
import re


class FileBrowser(DirectoryTree):
    """Enhanced DirectoryTree with double-click support."""
    
    class FileDoubleClicked(Message):
        """Custom message for double-click on file."""
        
        def __init__(self, path: Path) -> None:
            super().__init__()
            self.path = path
    
    def on_directory_tree_file_selected(self, event: DirectoryTree.FileSelected) -> None:
        """Handle file selection - show preview."""
        self.post_message(self.FileDoubleClicked(event.path))
    
    def on_click(self, event) -> None:
        """Handle mouse clicks for double-click detection."""
        if event.button == 1 and hasattr(event, 'count') and event.count == 2:
            # Get the file at the clicked position
            node = self.cursor_node
            if node and node.data:
                path = Path(node.data.path)
                if path.is_file():
                    self.post_message(self.FileDoubleClicked(path))


class FileEditor(TextArea):
    """Enhanced text editor widget with file operations."""
    
    def __init__(self, **kwargs) -> None:
        super().__init__(**kwargs)
        self.current_file: Path | None = None
        self.is_modified = False
        self.original_content = ""
    
    def load_file(self, file_path: Path) -> None:
        """Load and display a file's contents for editing."""
        self.current_file = file_path
        try:
            if file_path.is_file():
                # Read file contents
                content = file_path.read_text(encoding='utf-8', errors='ignore')
                
                # Strip ANSI escape sequences and other control characters
                ansi_escape = re.compile(r'\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])')
                content = ansi_escape.sub('', content)
                
                # Store original content for comparison
                self.original_content = content
                
                # Load content into TextArea
                self.text = content
                
                # Set syntax highlighting based on file extension
                self._set_language_from_extension(file_path.suffix)
                
                # Force syntax highlighting update
                self._force_syntax_highlighting()
                
                # Enable editing
                self.read_only = False
                self.is_modified = False
            else:
                # Show directory info
                dir_info = f"📁 Directory: {file_path.name}\n\nThis is a directory. Select a file to edit."
                self.text = dir_info
                self.read_only = True
                self.current_file = None
        except Exception as e:
            self.text = f"❌ Error loading file: {e}"
            self.read_only = True
            self.current_file = None
    
    def _force_syntax_highlighting(self) -> None:
        """Force syntax highlighting refresh after tree-sitter installation."""
        # Simply refresh the widget after setting language
        self.refresh()
    
    def _set_language_from_extension(self, extension: str) -> None:
        """Set syntax highlighting language based on file extension."""
        language_map = {
            '.py': 'python',
            '.js': 'javascript', 
            '.ts': 'typescript',
            '.jsx': 'javascript',
            '.tsx': 'typescript',
            '.html': 'html',
            '.css': 'css',
            '.scss': 'scss',
            '.json': 'json',
            '.yaml': 'yaml',
            '.yml': 'yaml',
            '.toml': 'toml',
            '.md': 'markdown',
            '.sh': 'bash',
            '.bash': 'bash',
            '.zsh': 'bash',
            '.rs': 'rust',
            '.go': 'go',
            '.java': 'java',
            '.c': 'c',
            '.cpp': 'cpp',
            '.h': 'c',
            '.hpp': 'cpp',
        }
        
        try:
            if extension.lower() in language_map:
                self.language = language_map[extension.lower()]
                # Debug: Show what language was set in the border title
                if hasattr(self, 'border_title'):
                    self.border_title = f"📝 File Editor ({self.language})"
            else:
                self.language = None  # Plain text
                if hasattr(self, 'border_title'):
                    self.border_title = "📝 File Editor (plain text)"
        except Exception:
            # If syntax highlighting fails, just use plain text
            self.language = None
            if hasattr(self, 'border_title'):
                self.border_title = "📝 File Editor (error)"
    
    def save_file(self) -> bool:
        """Save the current content to file."""
        if not self.current_file:
            return False
            
        try:
            self.current_file.write_text(self.text, encoding='utf-8')
            self.original_content = self.text
            self.is_modified = False
            return True
        except Exception:
            return False
    
    def on_text_area_changed(self, event) -> None:
        """Track modifications to the file."""
        if self.current_file:
            self.is_modified = self.text != self.original_content





class FileFinderProvider(Provider):
    """A command provider for fuzzy file finding using Textual's built-in fuzzy search."""
    
    async def startup(self) -> None:
        """Called when command palette opens - build file list."""
        worker = self.app.run_worker(self._get_files, thread=True)
        self.files = await worker.wait()
    
    def _get_files(self) -> list[Path]:
        """Get all files recursively in current directory."""
        try:
            all_files = []
            root_path = Path.cwd()
            
            # Get all files recursively, including hidden ones
            for pattern in ["**/*", "**/.*"]:
                try:
                    files = list(root_path.glob(pattern))
                    for f in files:
                        if f.is_file() and f not in all_files:
                            all_files.append(f)
                except Exception:
                    continue
            
            # Sort by name for consistent ordering
            all_files.sort(key=lambda x: str(x).lower())
            return all_files[:500]  # Limit for performance
            
        except Exception:
            return []
    
    async def search(self, query: str) -> Hits:
        """Search for files using Textual's fuzzy matcher."""
        if not hasattr(self, 'files'):
            return
            
        matcher = self.matcher(query)
        app = self.app
        
        if not isinstance(app, TextualJmux):
            return
        
        for file_path in self.files:
            try:
                # Get display path (relative if possible)
                try:
                    display_path = file_path.relative_to(Path.cwd())
                except ValueError:
                    display_path = file_path
                
                # Create search text with file type info
                file_name = display_path.name
                search_text = f"{file_name} {str(display_path)}"
                
                score = matcher.match(search_text)
                if score > 0:
                    # Add file type emoji
                    if file_path.suffix in ['.py', '.js', '.ts', '.jsx', '.tsx']:
                        icon = "🐍" if file_path.suffix == '.py' else "📜"
                    elif file_path.suffix in ['.md', '.txt', '.rst']:
                        icon = "📄"
                    elif file_path.suffix in ['.json', '.yaml', '.yml', '.toml']:
                        icon = "⚙️"
                    elif file_path.suffix in ['.sh', '.bash', '.zsh']:
                        icon = "🔧"
                    else:
                        icon = "📄"
                    
                    # Create highlighted display text
                    display_text = f"{icon} {display_path}"
                    
                    yield Hit(
                        score,
                        matcher.highlight(display_text),
                        partial(app._open_file_from_palette, file_path),
                        help=f"Open {file_path.name} in viewer"
                    )
                    
            except Exception:
                continue




class TabManager(ListView):
    """Vertical tab manager widget using ListView."""
    
    def __init__(self, **kwargs) -> None:
        super().__init__(**kwargs)
        self.tabs = []
        self.active_tab = 0
        # Disable focus for this widget - it should never be focused
        self.can_focus = False
    
    def add_tab(self, name: str, file_path: Path = None) -> int:
        """Add a new tab and return its index."""
        tab_index = len(self.tabs)
        self.tabs.append({
            'name': name,
            'file_path': file_path,
            'content': '',
            'is_modified': False
        })
        self.update_display()
        return tab_index
    
    def close_tab(self, tab_index: int) -> bool:
        """Close a tab. Returns True if successful."""
        if 0 <= tab_index < len(self.tabs) and len(self.tabs) > 1:
            self.tabs.pop(tab_index)
            # Adjust active tab if needed
            if self.active_tab >= len(self.tabs):
                self.active_tab = len(self.tabs) - 1
            elif self.active_tab > tab_index:
                self.active_tab -= 1
            self.update_display()
            return True
        return False
    
    def set_active_tab(self, tab_index: int) -> bool:
        """Set the active tab."""
        if 0 <= tab_index < len(self.tabs):
            self.active_tab = tab_index
            self.update_display()
            # Set the ListView index to match
            if tab_index < len(self.children):
                self.index = tab_index
            return True
        return False
    
    def update_display(self) -> None:
        """Update the visual display of tabs."""
        # Clear current items
        self.clear()
        
        if not self.tabs:
            return
        
        # Add each tab as a ListItem
        for i, tab in enumerate(self.tabs):
            prefix = "▶ " if i == self.active_tab else "  "
            modified = " *" if tab.get('is_modified', False) else ""
            name = tab['name'][:18] + ("..." if len(tab['name']) > 18 else "")
            
            label = Label(f"{prefix}{i+1}. {name}{modified}")
            list_item = ListItem(label)
            self.append(list_item)
    
    def on_list_view_selected(self, event: ListView.Selected) -> None:
        """Handle ListView selection."""
        tab_index = event.index
        if 0 <= tab_index < len(self.tabs):
            self.active_tab = tab_index
            self.update_display()
            self.post_message(TabManager.TabSwitched(tab_index))
    
    class TabSwitched(Message):
        """Message sent when tab is switched."""
        def __init__(self, tab_index: int) -> None:
            super().__init__()
            self.tab_index = tab_index


class TextualJmux(App):
    """Main Textual jmux application."""
    
    # Add our custom file finder to the command palette
    COMMANDS = App.COMMANDS | {FileFinderProvider}
    
    # Increase refresh rate for smoother animations
    FRAMES_PER_SECOND = 60  # Default is 30
    
    CSS = """
    Screen {
        layout: horizontal;
        background: $background;
    }
    
    .panel {
        border: solid $primary;
        margin: 1;
    }
    
    .left-panel {
        width: 40%;
        background: $surface;
    }
    
    .left-panel-focused {
        width: 40%;
        background: $surface;
    }
    
    .left-panel-unfocused {
        width: 20%;
        background: $surface;
    }
    
    .right-panel {
        width: 60%;
        background: $surface;
    }
    
    .right-panel-focused {
        width: 80%;
        background: $surface;
    }
    
    .right-panel-unfocused {
        width: 60%;
        background: $surface;
    }
    
    .middle-panel {
        width: 25%;
        background: $surface;
    }
    
    FileBrowser {
        padding: 1;
        background: $surface;
        color: $text;
        border-title-align: center;
    }
    
    TabManager {
        width: 100%;
        padding: 1;
        background: $surface;
        color: $text;
        border: solid $accent;
        border-title-align: center;
    }
    
    FileEditor {
        padding: 1;
        background: $panel;
        border-title-align: center;
        scrollbar-size: 1 1;
        scrollbar-size-horizontal: 1;
        scrollbar-size-vertical: 1;
    }
    
    /* Force syntax highlighting colors using proper Textual selectors */
    TextArea .syntax_highlight { }
    
    FileEditor .syntax_highlight .keyword { color: $accent; }
    FileEditor .syntax_highlight .string { color: $success; } 
    FileEditor .syntax_highlight .comment { color: $warning; }
    FileEditor .syntax_highlight .number { color: $error; }
    FileEditor .syntax_highlight .builtin { color: $primary; }
    FileEditor .syntax_highlight .function { color: $secondary; }
    
    Header {
        background: $primary;
        color: $text;
        text-align: center;
    }
    
    Footer {
        background: $primary;
        color: $text;
    }
    """
    
    BINDINGS = [
        ("colon", "command_palette", "File finder"),
        ("ctrl+c", "quit", "Quit"),
        ("ctrl+o", "open_in_nvim", "Open in nvim"),
        ("ctrl+s", "save_file", "Save file"),
        ("ctrl+w", "close_tab", "Close tab"),
        ("ctrl+tab", "next_tab", "Next tab"),
        ("ctrl+shift+tab", "prev_tab", "Previous tab"),
        ("f", "toggle_files", "Toggle files"),
        ("tab", "focus_next", "Focus next panel"),
        ("shift+tab", "focus_previous", "Focus previous panel"), 
        ("escape", "cancel", "Cancel"),
    ]
    
    current_file = reactive("")
    
    def compose(self) -> ComposeResult:
        """Create the application layout."""
        yield Header(show_clock=True)
        
        with Horizontal(id="main_horizontal"):
            # Left panel - File browser
            with Vertical(classes="left-panel panel", id="left_panel"):
                yield FileBrowser("./", id="file_browser")
            
            # Right panel - File editor with integrated tab manager
            with Vertical(classes="right-panel panel", id="right_panel"):
                with Horizontal():
                    # Tab manager (embedded in editor panel)
                    with Vertical(classes="middle-panel panel", id="middle_panel"):
                        yield TabManager(id="tab_manager")
                    # File editor with syntax highlighting enabled
                    yield FileEditor(
                        show_line_numbers=True,
                        theme="monokai",
                        id="file_editor"
                    )
        
        yield Footer()
    
    def on_ready(self) -> None:
        """Called when the app is ready."""
        # Set up titles
        file_browser = self.query_one("#file_browser", FileBrowser)
        file_editor = self.query_one("#file_editor", FileEditor)
        tab_manager = self.query_one("#tab_manager", TabManager)
        
        file_browser.border_title = "📁 File Browser"
        file_editor.border_title = "📝 File Editor"
        tab_manager.border_title = "📑 Open Tabs"
        
        # Initialize with a default tab
        tab_manager.add_tab("Welcome", None)
        
        # Set initial focus to file editor
        file_editor.focus()
        
        # Show initial welcome
        file_editor.text = (
            "🚀 Textual jmux - Enhanced Editor\n"
            "══════════════════════════════\n\n"
            "Welcome to the modern file editor!\n\n"
            "Features:\n"
            "• Full text editing with syntax highlighting\n"
            "• Dynamic panel sizing based on focus\n"
            "• Vertical tab system for multiple files\n"
            "• Tab: focus panels | Ctrl+Tab: switch tabs\n"
            "• Ctrl+S to save | : (colon) for fuzzy search\n"
            "• Ctrl+O to open in external nvim\n\n"
            "Select a file from the left panel to start editing."
        )
    
    def on_file_browser_file_double_clicked(self, event: FileBrowser.FileDoubleClicked) -> None:
        """Handle file selection - open in new tab or switch to existing tab."""
        file_path = event.path
        
        if not file_path.is_file():
            return
        
        tab_manager = self.query_one("#tab_manager", TabManager)
        
        # Check if file is already open in a tab
        for i, tab in enumerate(tab_manager.tabs):
            if tab.get('file_path') == file_path:
                tab_manager.set_active_tab(i)
                self._switch_to_tab(i)
                return
        
        # Open in new tab
        tab_index = tab_manager.add_tab(file_path.name, file_path)
        tab_manager.set_active_tab(tab_index)
        self._switch_to_tab(tab_index)
    
    def on_directory_tree_file_selected(self, event: DirectoryTree.FileSelected) -> None:
        """Handle single file selection - load in editor."""
        self.on_file_browser_file_double_clicked(
            FileBrowser.FileDoubleClicked(event.path)
        )
    
    def action_open_in_nvim(self) -> None:
        """Open current file in external nvim."""
        if not self.current_file:
            return
            
        file_path = Path(self.current_file)
        if not file_path.is_file():
            return
            
        try:
            # Check if we're in a tmux session
            if os.environ.get('TMUX'):
                # Open in new tmux pane
                subprocess.run([
                    'tmux', 'split-window', '-h', 
                    f'nvim "{file_path}"'
                ], check=True)
            else:
                # Open in new terminal
                subprocess.run([
                    'x-terminal-emulator', '-e', 
                    f'nvim "{file_path}"'
                ], check=False)  # Don't check=True to avoid errors
        except Exception:
            pass  # Silently handle errors
    
    def action_toggle_files(self) -> None:
        """Focus the file browser."""
        file_browser = self.query_one("#file_browser", FileBrowser)
        file_browser.focus()
        self._update_panel_sizes(file_browser)
    
    def action_focus_next(self) -> None:
        """Toggle focus between file browser and editor only."""
        focused = self.focused
        file_browser = self.query_one("#file_browser")
        file_editor = self.query_one("#file_editor")
        
        if focused == file_browser:
            file_editor.focus()
            self._update_panel_sizes(file_editor)
        else:
            file_browser.focus()
            self._update_panel_sizes(file_browser)
    
    def action_focus_previous(self) -> None:
        """Toggle focus between file browser and editor only."""
        # Same as focus_next since we only have two focusable panels
        self.action_focus_next()
    
    def action_save_file(self) -> None:
        """Save the current file."""
        file_editor = self.query_one("#file_editor", FileEditor)
        tab_manager = self.query_one("#tab_manager", TabManager)
        
        if file_editor.current_file and file_editor.save_file():
            # Update tab to show it's no longer modified
            if tab_manager.active_tab < len(tab_manager.tabs):
                tab_manager.tabs[tab_manager.active_tab]['is_modified'] = False
                tab_manager.update_display()
            
            # File saved successfully - update title
            file_editor.border_title = f"📝 {file_editor.current_file.name} ✓"
        else:
            # Show error in title
            file_editor.border_title = "📝 File Editor - Save Failed ❌"
    

    

    
    
    def _open_file_from_palette(self, file_path: Path) -> None:
        """Open a file selected from the command palette."""
        tab_manager = self.query_one("#tab_manager", TabManager)
        
        # Check if file is already open in a tab
        for i, tab in enumerate(tab_manager.tabs):
            if tab.get('file_path') == file_path:
                tab_manager.set_active_tab(i)
                self._switch_to_tab(i)
                return
        
        # Open in new tab
        tab_index = tab_manager.add_tab(file_path.name, file_path)
        tab_manager.set_active_tab(tab_index)
        self._switch_to_tab(tab_index)
    
    def _switch_to_tab(self, tab_index: int) -> None:
        """Switch the editor to show the specified tab."""
        tab_manager = self.query_one("#tab_manager", TabManager)
        
        if not (0 <= tab_index < len(tab_manager.tabs)):
            return
        
        tab = tab_manager.tabs[tab_index]
        file_path = tab.get('file_path')
        
        if file_path:
            self.current_file = str(file_path)
            
            # Update the file editor
            file_editor = self.query_one("#file_editor", FileEditor)
            file_editor.load_file(file_path)
            
            # Update border title with file info and language
            modified_indicator = " *" if file_editor.is_modified else ""
            language_info = f" ({file_editor.language})" if file_editor.language else ""
            file_editor.border_title = f"📝 {file_path.name}{modified_indicator}{language_info}"
        else:
            # Welcome tab or empty tab
            file_editor = self.query_one("#file_editor", FileEditor)
            file_editor.text = (
                "🚀 Textual jmux - Enhanced Editor\n"
                "══════════════════════════════\n\n"
                "Welcome to the modern file editor!\n\n"
                "Features:\n"
                "• Full text editing with syntax highlighting\n"
                "• Dynamic panel sizing based on focus\n"
                "• Vertical tab system for multiple files\n"
                "• Tab: focus panels | Ctrl+Tab: switch tabs\n"
                "• Ctrl+S to save | : (colon) for fuzzy search\n"
                "• Ctrl+O to open in external nvim\n\n"
                "Select a file from the left panel to start editing."
            )
            file_editor.read_only = True
            self.current_file = ""
    
    def on_tab_manager_tab_switched(self, event: TabManager.TabSwitched) -> None:
        """Handle tab switch from the tab manager."""
        self._switch_to_tab(event.tab_index)
    
    def on_focus(self, event) -> None:
        """Handle focus changes to resize panels dynamically."""
        self._update_panel_sizes(event.widget)
    
    def _update_panel_sizes(self, focused_widget) -> None:
        """Update panel sizes based on which widget has focus."""
        left_panel = self.query_one("#left_panel")
        right_panel = self.query_one("#right_panel")
        
        # Remove all dynamic classes first
        left_panel.remove_class("left-panel-focused", "left-panel-unfocused")
        right_panel.remove_class("right-panel-focused", "right-panel-unfocused")
        
        # Determine which panel contains the focused widget
        file_browser = self.query_one("#file_browser")
        file_editor = self.query_one("#file_editor")
        
        if focused_widget == file_browser or focused_widget.parent == left_panel:
            # File browser focused - expand left panel
            left_panel.add_class("left-panel-focused")
            right_panel.add_class("right-panel-unfocused")
        else:
            # Editor focused (default) - expand right panel
            left_panel.add_class("left-panel-unfocused")
            right_panel.add_class("right-panel-focused")
    
    def action_next_tab(self) -> None:
        """Switch to the next tab."""
        tab_manager = self.query_one("#tab_manager", TabManager)
        if len(tab_manager.tabs) > 1:
            next_tab = (tab_manager.active_tab + 1) % len(tab_manager.tabs)
            tab_manager.set_active_tab(next_tab)
            self._switch_to_tab(next_tab)
    
    def action_prev_tab(self) -> None:
        """Switch to the previous tab."""
        tab_manager = self.query_one("#tab_manager", TabManager)
        if len(tab_manager.tabs) > 1:
            prev_tab = (tab_manager.active_tab - 1) % len(tab_manager.tabs)
            tab_manager.set_active_tab(prev_tab)
            self._switch_to_tab(prev_tab)
    
    def action_close_tab(self) -> None:
        """Close the current tab."""
        tab_manager = self.query_one("#tab_manager", TabManager)
        
        if len(tab_manager.tabs) <= 1:
            return  # Don't close the last tab
        
        current_tab = tab_manager.active_tab
        if tab_manager.close_tab(current_tab):
            # Switch to the new active tab
            self._switch_to_tab(tab_manager.active_tab)
    
    def action_cancel(self) -> None:
        """Cancel any active operation."""
        pass
    
    async def action_quit(self) -> None:
        """Quit the application."""
        self.exit()


def main():
    """Entry point."""
    app = TextualJmux()
    app.run()


if __name__ == "__main__":
    main()