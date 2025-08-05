require_relative "../Library/UrlResolver"
require_relative "../Library/Icons"

class EmacsMacExpAT30 < Formula
  desc "YAMAMOTO Mitsuharu's Mac port of GNU Emacs - jdtsmith experimental"
  homepage "https://www.gnu.org/software/emacs/"

  @@urlResolver = UrlResolver.new(ENV["HOMEBREW_EMACS_MAC_MODE"] || "remote")

  head do
    url "https://github.com/jdtsmith/emacs-mac.git",
        **(
          if ENV["HOMEBREW_EMACS_MAC_30_REVISION"]
            { revision: ENV["HOMEBREW_EMACS_MAC_30_REVISION"] }
          else
            { branch: "emacs-mac-30_1_exp" }
          end
        )
  end
  option "without-modules", "Build without dynamic modules support"
  option "with-ctags", "Don't remove the ctags executable that emacs provides"
  option "with-no-title-bars",
         "Build with a patch for no title bars on frames (not recommended to use with --HEAD option)"

  option "with-natural-title-bar",
         "Build with a patch for title bar color inferred by theme (not recommended to use with --HEAD option)"

  option "with-starter", "Build with a starter script to start emacs GUI from CLI"
  option "with-mac-metal", "use Metal framework in application-side double buffering (experimental)"
  option "with-xwidgets", "Build with xwidgets"
  option "with-unlimited-select", "Builds with unlimited select, which increases emacs's open file limit to 10000"
  option "with-debug-flags", "Builds with gcc (llvm) debug flags, suitable for debugging with lldb"
  option "with-optimalization-flags", "Builds with gcc (llvm) optimalization flags"
  option "without-native-compilation", "Build without native compilation"

  deprecated_option "with-native-comp" => "with-native-compilation"
  deprecated_option "without-native-comp" => "without-native-compilation"
  deprecated_option "keep-ctags" => "with-ctags"
  deprecated_option "icon-official" => "with-official-icon"
  deprecated_option "icon-modern" => "with-modern-icon"

  depends_on "gcc" => :build if build.with? "native-compilation"
  depends_on "autoconf"
  depends_on "automake"
  depends_on "gnutls"
  depends_on "libgccjit" if build.with? "native-compilation"
  depends_on "pkg-config"
  depends_on "texinfo"
  depends_on "jansson" => :recommended
  depends_on "librsvg" => :recommended
  depends_on "libxml2" => :recommended
  depends_on "tree-sitter" => :recommended
  depends_on "dbus" => :optional
  depends_on "glib" => :optional
  depends_on "imagemagick" => :optional

  patch do
    # patch for multi-tty support, see the following links for details
    # https://bitbucket.org/mituharu/emacs-mac/pull-requests/2/add-multi-tty-support-to-be-on-par-with/diff
    # https://ylluminarious.github.io/2019/05/23/how-to-fix-the-emacs-mac-port-for-multi-tty-access/
    url (@@urlResolver.patch_url "emacs-mac-29.2-rc-1-multi-tty"), using: CopyDownloadStrategy
    sha256 "4ede698c8f8f5509e3abf4e6a9c73e1dc3909b0f52f52ad4c33068bfaed3d1e4"
  end

  patch do
    url (@@urlResolver.patch_url "prefer-typo-ascender-descender-linegap"), using: CopyDownloadStrategy
    sha256 "318395d3869d3479da4593360bcb11a5df08b494b995287074d0d744ec562c17"
  end

  patch do
    url (@@urlResolver.patch_url "emacs-30-inhibit-lexical-cookie-warning-67916"), using: CopyDownloadStrategy
    sha256 "5a37a127071db0a500281d13f7feae624ed6a93a2f66a73b565d7d39bdca0a16"
  end

  patch do
    url (@@urlResolver.patch_url "emacs-29-make-file-notify-call-handler-more-robust-78712"),
        using: CopyDownloadStrategy
    sha256 "496c5c058286aea8e13328d1e19425b958dff839a137d14ea2e74c3cf8d66351"
  end

  patch do
    url (@@urlResolver.patch_url "emacs-mac-29-suppress-noescape"), using: CopyDownloadStrategy
    sha256 "36740bcc4783ad12b155ed4d58682fc1803e9a6bcb6f9d5dbb89a94a8a1830d8"
  end

  # icons
  ICONS_INFO_EXP.each do |icon, iconsha|
    option "with-#{icon}", "Using Emacs icon: #{icon}"
    next if build.without? icon

    resource icon do
      url (@@urlResolver.icon_url icon), using: CopyDownloadStrategy
      sha256 iconsha
    end
  end

  if build.with? "no-title-bars"
    # odie "--with-no-title-bars patch not supported on --HEAD" if build.head?
    patch do
      url (@@urlResolver.patch_url "emacs-26.2-rc1-mac-7.5-no-title-bar"), using: CopyDownloadStrategy
      sha256 "8319fd9568037c170f5990f608fb5bd82cd27346d1d605a83ac47d5a82da6066"
    end
  end

  if build.with? "natural-title-bar"
    patch do
      url (@@urlResolver.patch_url "emacs-mac-title-bar-9.1"), using: CopyDownloadStrategy
      sha256 "297203d750c5c2d9f05aa68f1f47f1bda43419bf1b9ba63f8167625816c3a88d"
    end
  end

  def get_emacs_version
    ac_init_match=`m4 configure.ac`.match(/AC_INIT\(([^\)]+)\)/)
    version_arg=ac_init_match ? ac_init_match[1].split(",")[1] : nil
    version_match=version_arg ? version_arg.match(/([0-9.]+)/) : nil
    version_match ? version_match[1] : `#{bin}/emacs --version`.lines[0].sub(/^GNU Emacs /, "").chomp
  end

  def install
    args = [
      "--enable-locallisppath=#{HOMEBREW_PREFIX}/share/emacs/site-lisp",
      "--infodir=#{info}",
      "--mandir=#{man}",
      "--prefix=#{prefix}",
      "--with-mac",
      "--enable-mac-app=#{prefix}",
      "--with-gnutls",
    ]
    args << "--with-modules" if build.with? "modules"
    args << "--with-rsvg" if build.with? "rsvg"
    args << "--with-mac-metal" if build.with? "mac-metal"
    args << "--without-native-compilation" if build.without? "native-compilation"
    args << "--with-xwidgets" if build.with? "xwidgets"
    args << "--with-tree-sitter" if build.with? "tree-sitter"

    if build.with? "native-compilation"
      gcc_ver = Formula["gcc"].any_installed_version
      gcc_ver_major = gcc_ver.major
      gcc_lib="#{HOMEBREW_PREFIX}/lib/gcc/#{gcc_ver_major}"

      ENV.append "CFLAGS", "-I#{Formula["gcc"].include}"
      ENV.append "CFLAGS", "-I#{Formula["libgccjit"].include}"

      ENV.append "LDFLAGS", "-L#{gcc_lib}"
      ENV.append "LDFLAGS", "-I#{Formula["gcc"].include}"
      ENV.append "LDFLAGS", "-I#{Formula["libgccjit"].include}"
    end

    if build.with? "unlimited-select"
      ENV.append "CFLAGS", "-DFD_SETSIZE=10000"
      ENV.append "CFLAGS", "-DDARWIN_UNLIMITED_SELECT"
    end

    if build.with? "debug-flags"
      ENV.append "CFLAGS", "-O0" unless build.with? "optimalization-flags"
      ENV.append "CFLAGS", "-g3"
    end
    if build.with? "optimalization-flags"
      ENV.append "CFLAGS", "-O3"
      ENV.append "CFLAGS", "-mcpu=native"
    end

    icons_dir = buildpath/"mac/Emacs.app/Contents/Resources"
    ICONS_INFO_EXP.each do |icon,|
      next if build.without? icon

      rm "#{icons_dir}/Emacs.icns"
      resource(icon).stage do
        icons_dir.install Dir["*.icns*"].first => "Emacs.icns"
      end
    end

    system "./autogen.sh"
    system "./configure", *args
    system "make"
    system "make", "install"
    prefix.install "NEWS-mac"

    # Create symlinks in Emacs.app. This needs to happen before installing starter, as the latter requires native-lisp
    # directory in Emacs.app in order to call `emacs --version`.
    emacs_version = get_emacs_version
    contents_dir = prefix/"Emacs.app/Contents"
    [[lib/"emacs/#{emacs_version}/native-lisp", contents_dir],
     [share/"emacs/#{emacs_version}/lisp", contents_dir/"Resources"],
     [share/"emacs/#{emacs_version}/etc", contents_dir/"Resources"],
     [share/"info", contents_dir/"Resources"],
     [share/"man", contents_dir/"Resources"]].map do |source, target|
      target.install_symlink source if !File.exist? target/File.basename(source) and File.exist? source
    end

    # Follow Homebrew and don't install ctags from Emacs. This allows Vim
    # and Emacs and exuberant ctags to play together without violence.
    if build.without? "ctags"
      (bin/"ctags").unlink
      (share/man/man1/"ctags.1.gz").unlink
    end

    if build.with? "starter"
      # Replace the symlink with one that starts GUI
      # alignment the behavior with cask
      # borrow the idea from emacs-plus
      (bin/"emacs").unlink
      (bin/"emacs").write <<~EOS
        #!/bin/bash
        exec #{prefix}/Emacs.app/Contents/MacOS/Emacs.sh "$@"
      EOS
    end
  end

  def post_install
    (info/"dir").delete if (info/"dir").exist?
    info.glob("*.info{,.gz}") do |f|
      quiet_system Formula["texinfo"].bin/"install-info", "--quiet", "--info-dir=#{info}", f
    end
  end

  def caveats
    <<~EOS
      This is jdtsmith take on YAMAMOTO Mitsuharu's "Mac port" addition
      to GNU Emacs 30. This provides a native GUI support for Mac OS X
      10.10 - 15. After installing, see README-mac and NEWS-mac
      in #{prefix} for the port details.

      Emacs.app was installed to:
        #{prefix}

      To link the application to default App location and CLI scripts, please checkout:
        https://github.com/pkryger/homebrew-emacsmacport-exp/blob/master/docs/emacs-start-helpers.md

      If you are using Doom Emacs, be sure to run doom sync:
        ~/.emacs.d/bin/doom sync

      For an Emacs.app CLI starter, see:
        https://gist.github.com/4043945

      Emacs mac port also available on MacPorts with name "emacs-mac-app" and "emacs-mac-app-devel", but they are not maintained by the maintainer of this formula.
    EOS
  end

  test do
    assert_equal "4", shell_output("#{bin}/emacs --batch --eval=\"(print (+ 2 2))\"").strip
  end
end
