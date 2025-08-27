#!/usr/bin/env python3
"""
Textual jmux - A modern TUI file manager with integrated file editing
"""

from pathlib import Path
from textual.app import App, ComposeResult
from textual.containers import Horizontal, Vertical
from textual.widgets import DirectoryTree, Header, Footer, Static, Input, TextArea
from textual.reactive import reactive
from textual.message import Message
from textual.screen import ModalScreen
from textual.command import Provider, Hit, Hits
from functools import partial
import subprocess
import os
import fnmatch


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
                import re
                ansi_escape = re.compile(r'\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])')
                content = ansi_escape.sub('', content)
                
                # Store original content for comparison
                self.original_content = content
                
                # Load content into TextArea
                self.text = content
                
                # Set syntax highlighting based on file extension
                self._set_language_from_extension(file_path.suffix)
                
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
            else:
                self.language = None  # Plain text
        except Exception:
            # If syntax highlighting fails, just use plain text
            self.language = None
    
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




class TextualJmux(App):
    """Main Textual jmux application."""
    
    # Add our custom file finder to the command palette
    COMMANDS = App.COMMANDS | {FileFinderProvider}
    
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
        width: 45%;
        background: $surface;
    }
    
    .right-panel {
        width: 55%;
        background: $surface;
    }
    
    FileBrowser {
        padding: 1;
        background: $surface;
        color: $text;
        border-title-align: center;
    }
    
    FileEditor {
        padding: 1;
        background: $panel;
        color: $text;
        border-title-align: center;
        scrollbar-size: 1 1;
        scrollbar-size-horizontal: 1;
        scrollbar-size-vertical: 1;
    }
    
    Header {
        background: $primary;
        color: $text;
        text-align: center;
    }
    
    Footer {
        background: $primary;
        color: $text;
    }
    
    .status {
        height: 3;
        background: $surface;
        border: solid $accent;
        padding: 1;
    }
    """
    
    BINDINGS = [
        ("ctrl+p", "command_palette", "File finder"),
        ("ctrl+c", "quit", "Quit"),
        ("ctrl+o", "open_in_nvim", "Open in nvim"),
        ("ctrl+s", "save_file", "Save file"),
        ("f", "toggle_files", "Toggle files"),
        ("escape", "cancel", "Cancel"),
    ]
    
    current_file = reactive("")
    
    def compose(self) -> ComposeResult:
        """Create the application layout."""
        yield Header(show_clock=True)
        
        with Horizontal():
            # Left panel - File browser
            with Vertical(classes="left-panel panel"):
                yield FileBrowser("./", id="file_browser")
                yield Static(
                    "📁 Use ↑↓ or click to navigate\n"
                    "💾 Double-click to view files\n"
                    "⚡ Press : for commands (:q to quit)", 
                    classes="status",
                    id="browser_status"
                )
            
            # Right panel - File editor  
            with Vertical(classes="right-panel panel"):
                yield FileEditor(id="file_editor")
                yield Static(
                    "📝 File editor ready\n"
                    "🔍 Ctrl+P: fuzzy search | Ctrl+S: save\n"
                    "⌨️  Press : for vim commands", 
                    classes="status",
                    id="viewer_status"
                )
        
        yield Footer()
    
    def on_ready(self) -> None:
        """Called when the app is ready."""
        # Set up titles
        file_browser = self.query_one("#file_browser", FileBrowser)
        file_editor = self.query_one("#file_editor", FileEditor)
        
        file_browser.border_title = "📁 File Browser"
        file_editor.border_title = "📝 File Editor"
        
        # Show initial welcome
        file_editor.text = (
            "🚀 Textual jmux - Enhanced Editor\n"
            "══════════════════════════════\n\n"
            "Welcome to the modern file editor!\n\n"
            "Features:\n"
            "• Full text editing with syntax highlighting\n"
            "• Scroll support and cursor navigation\n"
            "• Ctrl+S to save files\n"
            "• Ctrl+P for fuzzy file search\n"
            "• Press : for vim-style commands\n"
            "• Ctrl+O to open in external nvim\n\n"
            "Select a file from the left panel to start editing."
        )
    
    def on_file_browser_file_double_clicked(self, event: FileBrowser.FileDoubleClicked) -> None:
        """Handle file selection - load in editor."""
        file_path = event.path
        self.current_file = str(file_path)
        
        # Update the file editor
        file_editor = self.query_one("#file_editor", FileEditor)
        file_editor.load_file(file_path)
        
        # Update status
        status = self.query_one("#viewer_status", Static)
        file_editor = self.query_one("#file_editor", FileEditor)
        modified_indicator = " *" if file_editor.is_modified else ""
        status.update(
            f"📝 Editing: {file_path.name}{modified_indicator}\n"
            f"📂 Path: {file_path}\n"
            f"⚡ Ctrl+S to save | :q to quit | Full editing enabled"
        )
    
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
    
    def action_save_file(self) -> None:
        """Save the current file."""
        file_editor = self.query_one("#file_editor", FileEditor)
        if file_editor.current_file and file_editor.save_file():
            status = self.query_one("#viewer_status", Static)
            status.update(
                f"✓ Saved: {file_editor.current_file.name}\n"
                f"📂 Path: {file_editor.current_file}\n"
                f"⚡ File saved successfully | :q to quit"
            )
        else:
            status = self.query_one("#viewer_status", Static)
            status.update(
                f"❌ Failed to save file\n"
                f"Make sure you have a file open and write permissions\n"
                f"⚡ Try again or select another file"
            )
    

    

    
    
    def _open_file_from_palette(self, file_path: Path) -> None:
        """Open a file selected from the command palette."""
        self.current_file = str(file_path)
        
        # Update the file editor
        file_editor = self.query_one("#file_editor", FileEditor)
        file_editor.load_file(file_path)
        
        # Update status
        status = self.query_one("#viewer_status", Static)
        status.update(
            f"📝 Editing: {file_path.name}\n"
            f"📂 Path: {file_path}\n"
            f"⚡ Ctrl+S to save | Ctrl+P to find more | :q to quit"
        )
    
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