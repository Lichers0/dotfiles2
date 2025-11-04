TPM_PATH := ~/.tmux/plugins/tpm

.PHONY: lazyvim

claude:
	ln -s $(PWD)/files/claude_desktop_config.json ~/Library/Application\ Support/Claude/claude_desktop_config.json | true

ccstatusline:
	ln -snf $(PWD)/files/ccstatusline ~/.config/ccstatusline | true

tmux:
	ln -s $(PWD)/files/tmux.conf ~/.tmux.conf | true

	@echo "🔍 Checking TPM..."
	@if [ ! -d $(TPM_PATH) ]; then \
		echo "📦 TPM not found. Installing..."; \
		git clone https://github.com/tmux-plugins/tpm $(TPM_PATH); \
	else \
		echo "✅ TPM already installed."; \
	fi
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
