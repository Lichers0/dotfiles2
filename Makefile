TPM_PATH := ~/.tmux/plugins/tpm

.PHONY: lazyvim

claude:
	@echo "Claude Desktop config contains secrets - configure manually:"
	@echo "  ~/Library/Application Support/Claude/claude_desktop_config.json"

ccstatusline:
	@echo "Setting up ccstatusline..."
	@mkdir -p ~/.config
	@rm -rf ~/.config/ccstatusline
	@ln -snf $(PWD)/ai/ccstatusline ~/.config/ccstatusline
	@echo "Done! Symlink: ~/.config/ccstatusline"

ghostty:
	@echo "Setting up Ghostty..."
	@mkdir -p ~/.config
	@rm -rf ~/.config/ghostty
	@ln -snf $(PWD)/ghostty ~/.config/ghostty
	@echo "Done! Symlink: ~/.config/ghostty"

tmux:
	ln -s $(PWD)/files/tmux.conf ~/.tmux.conf | true

	@echo "Checking TPM..."
	@if [ ! -d $(TPM_PATH) ]; then \
		echo "TPM not found. Installing..."; \
		git clone https://github.com/tmux-plugins/tpm $(TPM_PATH); \
	else \
		echo "TPM already installed."; \
	fi
	@ln -snf $(PWD)/tmux/plugins/tmux-ghostty-theme ~/.tmux/plugins/tmux-ghostty-theme
lazyvim:
	ln -snf $(PWD)/lazyvim ~/.config/nvim
astro:
	ln -snf $(PWD)/astro_vim4 ~/.config/nvim
test:
	rm -rf ~/.local/share/nvim || exit 0
	# rm -rf ~/.config/nvim || exit 0
nvim-configure:
	rm -rf nvim/plugin || exit 0
	rm -rf ~/.local/share/nvim || exit 0
	rm -rf ~/.config/nvim || exit 0
	rm -rf $(PACKER_PATH) || exit 0
	mkdir -p ~/.config
	mkdir -p $(PACKER_PATH)
	git clone --depth 1 https://github.com/wbthomason/packer.nvim $(PACKER_PATH)/packer.nvim
	ln -snf $(PWD)/nvim ~/.config/nvim

# git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
# git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
# ~/Library/Application Support/Claude/claude_desktop_config.json
# ~/.config/karabiner/

# MCP Servers for Claude Code
mcp:
	@echo "Setting up MCP servers..."
	@mkdir -p ~/.claude
	@ln -snf $(PWD)/ai/claude/mcp-servers ~/.claude/mcp-servers
	@ln -snf $(PWD)/ai/claude/mcp-init ~/.claude/mcp-init
	@# Create .env template if not exists
	@if [ ! -f ~/.claude/.env ]; then \
		echo "# MCP Servers API Keys" > ~/.claude/.env; \
		echo "BRAVE_API_KEY=" >> ~/.claude/.env; \
		echo "TAVILY_API_KEY=" >> ~/.claude/.env; \
		echo "BRIGHTDATA_API_TOKEN=" >> ~/.claude/.env; \
		echo "GITHUB_API_KEY=" >> ~/.claude/.env; \
		echo "EXA_API_KEY=" >> ~/.claude/.env; \
		echo "Created ~/.claude/.env - fill in your API keys"; \
	fi
	@# Add to .zshrc if not present
	@if ! grep -q "MCP Servers" ~/.zshrc 2>/dev/null; then \
		echo "" >> ~/.zshrc; \
		echo "# MCP Servers - load API keys" >> ~/.zshrc; \
		echo '[[ -f ~/.claude/.env ]] && { set -a; source ~/.claude/.env; set +a; }' >> ~/.zshrc; \
		echo "" >> ~/.zshrc; \
		echo "# MCP init alias" >> ~/.zshrc; \
		echo 'alias mcp-init="~/.claude/mcp-init"' >> ~/.zshrc; \
		echo "Added MCP config to ~/.zshrc"; \
	fi
	@echo "Done! Run: source ~/.zshrc"
