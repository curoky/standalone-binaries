# CPython — versioned static runtime profile.
#
# Why local:
# 1. The standalone Linux runtime cannot load the usual shared extension-module
#    set, so each selected CPython major receives an explicit `Setup.local` that
#    compiles the supported modules into the interpreter.
# 2. Built-in readline still needs termcap at final link time; add its library
#    path explicitly to the static link flags.
# 3. IDLE, the test tree and Tkinter are intentionally removed because this is
#    a compact command-line runtime, not a complete development distribution.
#
# These are structural runtime choices, not temporary upstream regressions.
{
  termcap,
}:
{
  python,
  setupLocal,
}:
python.overrideAttrs (oldAttrs: {
  configureFlags = oldAttrs.configureFlags ++ [
    "LDFLAGS=-L${termcap}/lib"
  ];
  stripIdlelib = true;
  stripTests = true;
  stripTkinter = true;
  postPatch = oldAttrs.postPatch + ''
    cp ${setupLocal} Modules/Setup.local
  '';
})
