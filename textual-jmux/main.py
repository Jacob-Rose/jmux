#!/usr/bin/env python3
"""
Textual jmux - A modern TUI file manager with integrated file editing
"""

from pathlib import Path
from textual.app import App, ComposeResult
from textual.containers import Horizontal, Vertical
from textual.widgets import DirectoryTree, Header, Footer, Static, Input
from textual.reactive import reactive
from textual.message import Message
from textual.screen import ModalScreen
import subprocess
import os


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


class FileViewer(Static):
    """Widget to display file contents."""
    
    def __init__(self, **kwargs) -> None:
        super().__init__(**kwargs)
        self.current_file: Path | None = None
    
    def load_file(self, file_path: Path) -> None:
        """Load and display a file's contents."""
        self.current_file = file_path
        try:
            if file_path.is_file():
                # Read file contents
                content = file_path.read_text(encoding='utf-8', errors='ignore')
                # Limit content size for display
                if len(content) > 10000:
                    content = content[:10000] + "\n\n... (file truncated, too large to display)"
                
                # Strip ANSI escape sequences and other control characters
                import re
                # Remove ANSI escape sequences
                ansi_escape = re.compile(r'\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])')
                content = ansi_escape.sub('', content)
                
                # Create a nice header
                header = f"📄 {file_path.name}\n{'─' * 50}\n"
                # Use Rich Text object to prevent markup parsing
                from rich.text import Text
                display_text = Text(header + content, no_wrap=False)
                self.update(display_text)
            else:
                self.update(f"📁 {file_path.name}\n{'─' * 50}\n\nDirectory selected. Navigate to view files.")
        except Exception as e:
            self.update(f"❌ Error loading file: {e}")


class CommandScreen(ModalScreen[str]):
    """Vim-style command input screen."""
    
    CSS = """
    CommandScreen {
        align: center middle;
    }
    
    #command_dialog {
        width: 60%;
        height: auto;
        background: $panel;
        border: solid $primary;
        padding: 1;
    }
    
    #command_input {
        width: 100%;
        margin-bottom: 1;
    }
    
    #command_help {
        color: $text-muted;
        text-align: center;
    }
    """
    
    def compose(self) -> ComposeResult:
        with Vertical(id="command_dialog"):
            yield Static("Command Mode (vim-style)", id="command_title")
            yield Input(placeholder="Enter command (e.g., :q, :quit, :o filename)", id="command_input")
            yield Static(
                "Available commands: :q :quit (exit) | :o <file> (open) | :e <file> (edit)",
                id="command_help"
            )
    
    def on_mount(self) -> None:
        """Focus the input when screen opens."""
        input_widget = self.query_one("#command_input", Input)
        input_widget.focus()
    
    def on_input_submitted(self, event: Input.Submitted) -> None:
        """Handle command submission."""
        command = event.value.strip()
        if command:
            self.dismiss(command)
        else:
            self.dismiss("")
    
    def on_key(self, event) -> None:
        """Handle escape to cancel."""
        if event.key == "escape":
            self.dismiss("")


class TextualJmux(App):
    """Main Textual jmux application."""
    
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
    
    FileViewer {
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
        ("colon", "command_mode", "Command mode"),
        ("ctrl+c", "quit", "Quit"),
        ("ctrl+o", "open_in_nvim", "Open in nvim"),
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
            
            # Right panel - File viewer  
            with Vertical(classes="right-panel panel"):
                yield FileViewer(id="file_viewer")
                yield Static(
                    "📄 File content appears here\n"
                    "🔍 Select files to preview\n"
                    "⌨️  Press : for vim commands", 
                    classes="status",
                    id="viewer_status"
                )
        
        yield Footer()
    
    def on_ready(self) -> None:
        """Called when the app is ready."""
        # Set up titles
        file_browser = self.query_one("#file_browser", FileBrowser)
        file_viewer = self.query_one("#file_viewer", FileViewer)
        
        file_browser.border_title = "📁 File Browser"
        file_viewer.border_title = "📄 File Viewer"
        
        # Show initial welcome
        file_viewer.update(
            "🚀 Textual jmux\n"
            "═══════════════\n\n"
            "Welcome to the modern file manager!\n\n"
            "Features:\n"
            "• Navigate with mouse or keyboard\n"
            "• Double-click files to preview\n"
            "• Press : for vim-style commands (:q to quit)\n"
            "• Ctrl+O to open in external nvim\n"
            "• Built with Python + Textual\n\n"
            "Select a file from the left panel to get started."
        )
    
    def on_file_browser_file_double_clicked(self, event: FileBrowser.FileDoubleClicked) -> None:
        """Handle file selection - show in right panel."""
        file_path = event.path
        self.current_file = str(file_path)
        
        # Update the file viewer
        file_viewer = self.query_one("#file_viewer", FileViewer)
        file_viewer.load_file(file_path)
        
        # Update status
        status = self.query_one("#viewer_status", Static)
        status.update(
            f"📄 Viewing: {file_path.name}\n"
            f"📂 Path: {file_path}\n"
            f"⚡ :o to open in nvim | :q to quit"
        )
    
    def on_directory_tree_file_selected(self, event: DirectoryTree.FileSelected) -> None:
        """Handle single file selection - preview."""
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
    
    def action_command_mode(self) -> None:
        """Open vim-style command mode."""
        def handle_command_result(command: str | None) -> None:
            if command:
                self.run_worker(self.handle_command(command))
        
        self.push_screen(CommandScreen(), handle_command_result)
    
    async def handle_command(self, command: str) -> None:
        """Handle vim-style commands."""
        command = command.strip()
        
        # Remove leading : if present
        if command.startswith(':'):
            command = command[1:]
        
        parts = command.split()
        if not parts:
            return
        
        cmd = parts[0].lower()
        
        if cmd in ['q', 'quit']:
            self.exit()
        elif cmd in ['o', 'open'] and len(parts) > 1:
            # :o filename - open file
            filename = ' '.join(parts[1:])
            await self.open_file_by_name(filename)
        elif cmd in ['e', 'edit'] and len(parts) > 1:
            # :e filename - edit file in external nvim
            filename = ' '.join(parts[1:])
            await self.edit_file_by_name(filename)
        else:
            # Show error for unknown commands
            status = self.query_one("#viewer_status", Static)
            status.update(
                f"❌ Unknown command: {command}\n"
                f"Available: :q :quit :o <file> :e <file>\n"
                f"Press : to try again"
            )
    
    async def open_file_by_name(self, filename: str) -> None:
        """Open a file by name in the viewer."""
        try:
            file_path = Path(filename)
            if not file_path.is_absolute():
                file_path = Path.cwd() / file_path
            
            if file_path.exists():
                self.current_file = str(file_path)
                file_viewer = self.query_one("#file_viewer", FileViewer)
                file_viewer.load_file(file_path)
                
                status = self.query_one("#viewer_status", Static)
                status.update(
                    f"📄 Opened: {file_path.name}\n"
                    f"📂 Path: {file_path}\n"
                    f"⚡ :o to open in nvim | :q to quit"
                )
            else:
                status = self.query_one("#viewer_status", Static)
                status.update(f"❌ File not found: {filename}")
        except Exception as e:
            status = self.query_one("#viewer_status", Static)
            status.update(f"❌ Error opening file: {e}")
    
    async def edit_file_by_name(self, filename: str) -> None:
        """Open a file by name in external nvim."""
        try:
            file_path = Path(filename)
            if not file_path.is_absolute():
                file_path = Path.cwd() / file_path
            
            if file_path.exists():
                self.current_file = str(file_path)
                self.action_open_in_nvim()
            else:
                status = self.query_one("#viewer_status", Static)
                status.update(f"❌ File not found: {filename}")
        except Exception as e:
            status = self.query_one("#viewer_status", Static)
            status.update(f"❌ Error: {e}")
    
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