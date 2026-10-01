{
  pkgs,
  pkgsStatic,
}:
{
  # Resource bundles.
  rime-plugins = pkgsStatic.callPackage ../rime-plugins { };
  tmux-plugins = pkgsStatic.callPackage ../tmux-plugins { };
  vim-plugins = pkgs.callPackage ../vim-plugins { };
  zsh-plugins = pkgsStatic.callPackage ../zsh-plugins {
    nativeAtuin = pkgs.atuin;
    nativeStarship = pkgs.starship;
    nativeZsh = pkgs.zsh;
  };

  # C / autotools.
  autoconf = pkgsStatic.callPackage ../autoconf { };
  automake = pkgsStatic.callPackage ../automake { };
  curl = pkgsStatic.callPackage ../curl { };
  eza-ls = pkgsStatic.callPackage ../eza-ls { };
  file = pkgsStatic.callPackage ../file { };
  gnupg = pkgsStatic.gnupg.override {
    enableMinimal = true;
    guiSupport = false;
  };
  libtool = pkgsStatic.callPackage ../libtool { };
  makeself = pkgsStatic.callPackage ../makeself { };
  pkgconf = pkgsStatic.callPackage ../pkgconf { };
  vim = pkgsStatic.callPackage ../vim { };
  watchexec = pkgsStatic.callPackage ../watchexec { };
  zsh = pkgsStatic.callPackage ../zsh { };

  # Sibling-runtime wrappers.
  git-filter-repo = pkgs.callPackage ../git-filter-repo { };
  netron = pkgs.callPackage ../netron { };
  cloc = pkgs.callPackage ../cloc { };
  parallel = pkgs.callPackage ../parallel { };

}
