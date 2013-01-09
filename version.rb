def version()

  hash = `git rev-parse --short HEAD`.chomp
  # 0.pre to make debian consider any pre-release cut from git
  # version of the package to be _older_ than the last CI build.
  v_part = ENV['BUILD_NUMBER'] || "0.pre.#{hash}"
  return "0.0.#{v_part}"
end

