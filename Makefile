tmux:
	ln -s $(PWD)/files/tmux.conf ~/.tmux.conf | true
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
