# select

This is pure nix library to get elements/lists/attrs from nested list/attrs

Examples:

## All selector for dicts

```nix
select "nixosConfigurations.*.config.networking.hostName" flake
```

returns:
```nix
{
  machine1 = "machine1";
  machine2 = "machine2";
}
```


## multi select for dicts

```nix
select "nixosConfigurations.ignavia.config.services.{sshd,nginx}.enable" flake
```

returns:
```nix
{
  nginx = false;
  sshd = true;
}
```

## quoted select with dicts

```nix
select ''nixosConfigurations.ignavia.config.environment.etc."tmpfiles.d".enable'' flake
```

returns:
```nix
true
```

## maybe selector

### existing target

```nix
select "nixosConfigurations.ignavia.config.networking.?hostName" flake
```

returns:
```nix
{ hostName = "ignavia"; }
```

### not existing target

```nix
select "nixosConfigurations.ignavia.config.networking.?hostname" flake
```

returns:
```nix
{ }
```

### can also be used inside a set selector

```nix
select "nixosConfigurations.ignavia.config.networking.{?hostname,?hostName,iproute2}" flake
```

returns:
```nix
{
  hostName = "ignavia";
  iproute2 = {
    enable = false;
    rttablesExtraConfig = "";
  };
}
```

## list selector

```nix
select "nixosConfigurations.ignavia.config.environment.systemPackages.0.meta.homepage" flake
```

returns:
```nix
"https://github.com/FrameworkComputer/framework-system"
```

## list multi selector

```nix
select "nixosConfigurations.ignavia.config.environment.systemPackages.{0,3}.meta.homepage" flake
```

returns:
```nix
[
  "https://github.com/FrameworkComputer/framework-system"
  "https://gitlab.gnome.org/GNOME/adwaita-icon-theme"
]
```

## all list selector

```nix
select "nixosConfigurations.ignavia.config.fonts.fonts.*.outPath" flake
```

returns:
```nix
[
  "/nix/store/483n4m9sc7032ir7lpi68wd950di3aai-font-schumacher-misc-1.1.3"
  "/nix/store/2kdz6jkyvyjlzilakjdc4kfdcq7rmyiz-inconsolata-3.001"
  "/nix/store/szij13xqprlhpmz269ncrhq47mhy8ad1-noto-fonts-2025.02.01"
  "/nix/store/vb6yvgp0kvnv15hssq5iarxl1ikw0c5n-nerd-fonts-iosevka-3.3.0+29.0.4"
  "/nix/store/nkncn829spkjiggf37n9zdzyqvgx52l8-nerd-fonts-iosevka-term-3.3.0+29.0.4"
  "/nix/store/63mbnwkc2cf0l484hfdrgc024g81xyh7-dejavu-fonts-2.37"
  "/nix/store/s1v7id72bdy9qllmvncxp534bscd69jz-freefont-ttf-20120503"
  "/nix/store/jhb803vy842zfmyck4yah2skfkzf55nl-gyre-fonts-2.005"
  "/nix/store/raqihn82mwkhgxqwbbina293ps9b71ll-liberation-fonts-2.1.5"
  "/nix/store/k7nk5fr9jhayjgakm4sq9qa3i6i9kpjm-unifont-16.0.02"
  "/nix/store/w0g1f3w8j7gkg6y44w514ipr900yjw57-noto-fonts-color-emoji-2.047"
  "/nix/store/g1a26g9yf7jbzaashcxpxyz8383g0gvp-ghostscript-with-X-10.04.0-fonts"
]
```
