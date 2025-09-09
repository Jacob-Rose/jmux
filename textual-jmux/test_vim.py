#!/usr/bin/env python3
"""
Test case for textual-vim integration
"""

import tempfile
import sys
from pathlib import Path
from textual.app import App, ComposeResult
from textual.containers import Vertical, Horizontal
from textual.widgets import Header, Footer
from textual_vim import Vim

class VimTestApp(App):
    """Test app for textual-vim widget."""
    
    CSS = """
    Screen {
        background: $background;
    }
    
    Vim {
        border: solid $primary;
        padding: 1;
    }
    """
    
    BINDINGS = [
        ("ctrl+c", "quit", "Quit"),
        ("ctrl+s", "save_file", "Save"),
    ]
    
    def __init__(self, test_file=None):
        super().__init__()
        self.test_file = test_file
    
    def compose(self) -> ComposeResult:
        yield Header(show_clock=True)
        with Vertical():
            yield Vim(id="vim_editor")
        yield Footer()
    
    def on_mount(self) -> None:
        vim = self.query_one("#vim_editor", Vim)
        vim.focus()
        
        # Load test file if provided
        if self.test_file and self.test_file.exists():
            vim.load_file(str(self.test_file))
    
    def action_save_file(self) -> None:
        """Save the current file."""
        vim = self.query_one("#vim_editor", Vim)
        if hasattr(vim, 'save_file'):
            vim.save_file()
        else:
            # Fallback if save_file method doesn't exist
            self.bell()

def test_vim_widget_creation():
    """Test basic vim widget creation."""
    vim = Vim()
    assert vim is not None
    print("✓ Vim widget created successfully")

def test_vim_app():
    """Test vim app creation with test file."""
    # Create a test file
    with tempfile.NamedTemporaryFile(mode='w', suffix='.py', delete=False) as f:
        f.write("# Test file\nprint('Hello from textual-vim!')\n")
        test_file = Path(f.name)
    
    try:
        # Create app with test file
        app = VimTestApp(test_file)
        assert app is not None
        print("✓ VimTestApp created successfully")
        print(f"✓ Test file created: {test_file}")
        
        # Note: We can't easily test the app running without user interaction
        # This would require the full textual testing framework
        
    finally:
        # Clean up
        test_file.unlink(missing_ok=True)

def test_vim_methods():
    """Test vim widget methods."""
    vim = Vim()
    
    # Test basic methods exist
    methods_to_check = ['focus', 'blur']
    for method in methods_to_check:
        if hasattr(vim, method):
            print(f"✓ Vim has {method} method")
        else:
            print(f"! Vim missing {method} method")
    
    # Check if vim has load_file method
    if hasattr(vim, 'load_file'):
        print("✓ Vim has load_file method")
    else:
        print("! Vim missing load_file method")

def run_interactive_demo():
    """Run an interactive demo of textual-vim."""
    print("Starting interactive textual-vim demo...")
    print("Press Ctrl+C to quit")
    
    # Create a demo file
    with tempfile.NamedTemporaryFile(mode='w', suffix='.py', delete=False) as f:
        f.write("""#!/usr/bin/env python3
# Demo file for textual-vim
# Try vim commands like:
# i - insert mode
# ESC - normal mode  
# :w - save (if supported)
# :q - quit

def hello():
    print("Hello from textual-vim!")
    print("This is a test file.")

if __name__ == "__main__":
    hello()
""")
        demo_file = Path(f.name)
    
    try:
        app = VimTestApp(demo_file)
        app.run()
    except KeyboardInterrupt:
        print("\nDemo interrupted by user")
    finally:
        demo_file.unlink(missing_ok=True)

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "demo":
        run_interactive_demo()
    else:
        print("Running textual-vim tests...")
        
        try:
            test_vim_widget_creation()
            test_vim_app() 
            test_vim_methods()
            
            print("\n✅ All tests passed!")
            print("\nTo run interactive demo:")
            print("python test_vim.py demo")
            
        except Exception as e:
            print(f"❌ Test failed: {e}")
            import traceback
            traceback.print_exc()