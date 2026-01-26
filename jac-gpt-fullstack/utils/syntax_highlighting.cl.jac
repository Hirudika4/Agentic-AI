"""Monaco syntax highlighting utilities for Jac language (TextMate grammar)."""

import from "monaco-textmate" { Registry }
import from "monaco-editor-textmate" { wireTmGrammars }
import from "onigasm" { loadWASM }

# CORRECTED PATHS - Use absolute paths from web root
glob ONIG_WASM_PATH = "/static/assets/onigasm.wasm";
glob LANGUAGE_CONFIG_PATH = "/static/assets/language-configuration.json";

glob wasmInitialized = false;
glob languageRegistered = false;
glob grammarLoaded = false;
glob themeRegistered = false;

glob cachedGrammarConfig = null;
glob cachedRegistry = null;
glob cachedGrammarMap = null;

"""Load Jac syntax highlighting with TextMate grammar."""
async def:pub loadSyntax(monaco: any, editor: any) -> any {
    try {
        # Register language if not already registered
        if not languageRegistered {
            monaco.languages.register({ id: "jac" });
            languageRegistered = true;
        }
        
        # Load WASM only once
        if not wasmInitialized {
            await loadWASM(ONIG_WASM_PATH);
            wasmInitialized = true;
        }
        
        # Load grammar only once
        if not grammarLoaded {
            
            # Fetch Jac grammar from GitHub
            response = await fetch("https://raw.githubusercontent.com/jaseci-labs/jac-vscode/main/syntaxes/jac.tmLanguage.json");
            
            if not response.ok {
                raise Reflect.construct(Error, [f"Failed to fetch grammar: {response.status}"]);
            }
            
            grammarConfigRes = await fetch(LANGUAGE_CONFIG_PATH);
            
            if not grammarConfigRes.ok {
                raise Reflect.construct(Error, [f"Failed to fetch language config: {grammarConfigRes.status}"]);
            }
            
            jacGrammar = await response.json();
            cachedGrammarConfig = await grammarConfigRes.json();
            
            # Create TextMate registry
            registry = Reflect.construct(Registry, [{
                getGrammarDefinition: lambda {
                    return {
                        format: "json",
                        content: JSON.stringify(jacGrammar)
                    };
                }
            }]);
            
            cachedRegistry = registry;
            
            # Create grammar map
            grammar = Reflect.construct(Map, []);
            grammar.set("jac", "source.jac");
            cachedGrammarMap = grammar;
            
            grammarLoaded = true;
        }
        
        # Wire grammar to editor
        if editor and cachedRegistry and cachedGrammarMap {
            await wireTmGrammars(monaco, cachedRegistry, cachedGrammarMap, editor);
        }
        # 
        return cachedGrammarConfig;
        
    } except Exception as error {
        return null;
    }
}

"""Configure Monaco theme with Jaseci Orange colors."""
async def:pub configureTheme(monaco: any, grammarConfig: any, isDark: bool = true) {
    try {
        
        # Set language configuration
        if grammarConfig {
            monaco.languages.setLanguageConfiguration("jac", grammarConfig);
        }
        
        # Define Jaseci Orange theme (only once)
        if not themeRegistered {
            monaco.editor.defineTheme("jac-theme", {
                base: "vs-dark",
                inherit: true,
                rules: [
                    # Keywords - Orange
                    { token: "storage.type.class.jac", foreground: "f97316", fontStyle: "bold" },
                    { token: "storage.type.function.jac", foreground: "f97316", fontStyle: "bold" },
                    { token: "keyword.control.flow.jac", foreground: "f97316", fontStyle: "bold" },
                    { token: "keyword.control.import.jac", foreground: "f97316" },
                    { token: "storage.type.has.jac", foreground: "f97316" },
                    { token: "storage.modifier.declaration.jac", foreground: "f97316" },
                    
                    # Class/Function Names - Amber
                    { token: "entity.name.type.class.jac", foreground: "fbbf24" },
                    { token: "entity.name.function.jac", foreground: "fbbf24" },
                    
                    # Types - Light Orange
                    { token: "support.type.jac", foreground: "fb923c" },
                    { token: "constant.language.jac", foreground: "fb923c" },
                    
                    # Strings - Green
                    { token: "string.quoted.single.jac", foreground: "86efac" },
                    { token: "string.quoted.double.jac", foreground: "86efac" },
                    { token: "string.interpolated.jac", foreground: "86efac" },
                    
                    # Numbers - Purple
                    { token: "constant.numeric.jac", foreground: "c084fc" },
                    
                    # Comments - Gray
                    { token: "comment.line.jac", foreground: "6b7280", fontStyle: "italic" },
                    { token: "comment.block.jac", foreground: "6b7280", fontStyle: "italic" },
                    
                    # Variables - Light Blue
                    { token: "variable.parameter.jac", foreground: "93c5fd" },
                    { token: "variable.language.special.self.jac", foreground: "93c5fd" }
                ],
                colors: {
                    "editor.background": "#1a1b1e",
                    "editor.foreground": "#e4e4e7",
                    "editorLineNumber.foreground": "#6b7280",
                    "editorLineNumber.activeForeground": "#f97316",
                    "editorCursor.foreground": "#f97316",
                    "editor.selectionBackground": "#f9731633"
                }
            });
            
            themeRegistered = true;
        }
        
        # Apply theme
        monaco.editor.setTheme("jac-theme");
        
    } except Exception as error{
    }
}