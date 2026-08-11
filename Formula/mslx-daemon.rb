class MslxDaemon < Formula
  desc "Cross-platform Minecraft Server Manager"
  homepage "https://mslx.mslmc.cn/"

  version "1.5.10"

  license "AGPL-3.0"

  if Hardware::CPU.arm?
    url "https://github.com/MSLTeam/MSLX/releases/download/v1.5.10/MSLX-Daemon_v1.5.10_osx-arm64.tar.gz"
    sha256 "f9bb9616e12155e980eaf31fe2ea368855cd342a60e8abc87b262d307be2b3e8"
  end

  if Hardware::CPU.intel?
    url "https://github.com/MSLTeam/MSLX/releases/download/v1.5.10/MSLX-Daemon_v1.5.10_osx-x64.tar.gz"
    sha256 "706b186bcc391b321fac580653233cc9b94c50b8bd683229a4c8992f7e0380e4"
  end

  livecheck do
    url "https://github.com/MSLTeam/MSLX.git"
    strategy :github_latest
  end

  depends_on "dotnet"
  depends_on :macos

  def install
    libexec.mkpath
    libexec.install "MSLX-Daemon"
    (bin/"mslx").write <<~EOS
      #!/bin/bash
      export PATH="/usr/local/bin:$PATH"
      export PATH="/opt/homebrew/bin:$PATH"
      export DOTNET_ROOT="$(brew --prefix dotnet)/libexec"
      export PATH="$(brew --prefix dotnet)/libexec:$PATH"
      DATA_DIR="$HOME/Library/Application Support/MSLX/MSLXData"
      DAEMON_DATA="$DATA_DIR/DaemonData"
      DATA_LINK="#{libexec}/DaemonData"
      INIT_LOG="$DATA_DIR/mslx-init.log"
      ACCOUNT_FILE="$DAEMON_DATA/默认账户信息.txt"

      mkdir -p "$DATA_DIR" "$DAEMON_DATA"
      if [ -e "$DATA_LINK" ] && [ ! -L "$DATA_LINK" ]; then
        cp -R "$DATA_LINK/." "$DAEMON_DATA/"
        rm -rf "$DATA_LINK"
      fi
      ln -sfn "$DAEMON_DATA" "$DATA_LINK"

      cd "#{libexec}"
      if ! command -v $(brew --prefix dotnet)/libexec/dotnet &> /dev/null; then
        echo "错误：.NET 运行时未正确安装，请运行 'brew install dotnet'" >&2
        exit 1
      fi
      if [ ! -f "$INIT_LOG" ]; then
        echo "=== MSLX 首次运行初始化 - $(date) ===" > "$INIT_LOG"
        "#{libexec}/MSLX-Daemon" >> "$INIT_LOG" 2>&1 &
        DAEMON_PID=$!
        trap 'kill "$DAEMON_PID" 2>/dev/null || true' INT TERM EXIT
        while [ ! -f "$ACCOUNT_FILE" ] && kill -0 "$DAEMON_PID" 2>/dev/null; do
          sleep 1
        done
        if [ ! -f "$ACCOUNT_FILE" ]; then
          wait "$DAEMON_PID"
          STATUS=$?
          rm -f "$INIT_LOG"
          echo "错误：未生成默认账户信息文件" >&2
          [ "$STATUS" -ne 0 ] && exit "$STATUS"
          exit 1
        fi
        open "$ACCOUNT_FILE"
        wait "$DAEMON_PID"
        STATUS=$?
        trap - INT TERM EXIT
        exit "$STATUS"
      else
        exec "#{libexec}/MSLX-Daemon"
      fi
    EOS
    chmod "+x", bin/"mslx"
  end

  service do
    run [opt_bin/"mslx"]
    keep_alive true
    log_path var/"log/mslx.log"
    error_log_path var/"log/mslx-error.log"
  end

  def caveats
    <<~EOS
      安装完成。请启动 MSLX-Daemon 服务：
        brew services start mslx-daemon

      数据目录: ~/Library/Application Support/MSLX/MSLXData/DaemonData
      安装日志: ~/Library/Application Support/MSLX/MSLXData/mslx-init.log
      运行日志: #{var}/log/mslx.log

      如需停止服务，请运行：
        brew services stop mslx-daemon

      如需彻底卸载（包括用户数据），请运行：
        brew zap mslx-daemon
    EOS
  end

  def zap
    data_dir = Dir.home/"Library/Application Support/MSLX/MSLXData/DaemonData"
    data_dir.rm_r if data_dir.exist?
    init_log = Dir.home/"Library/Application Support/MSLX/MSLXData/mslx-init.log"
    init_log.delete if init_log.exist?
  end

  test do
    assert_path_exists bin/"mslx"
    assert_predicate bin/"mslx", :executable?
    assert_path_exists libexec/"MSLX-Daemon",
                       "Main executable not found"
  end
end
