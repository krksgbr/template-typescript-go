{ pkgs, lib, self, ... }:

let
  sshKeys = [
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC2pY+vWgl2mQReP8teDuXfXmUI2EqT+phnvBkjJFdrAok+pZe7V6CHjxrhJZ1RMHZeadSyYUyfK4YdQvJh86irk1Ri5BTL3vBmnbCPS+T86181kL+xDctjk0H0ypFY3Mzn7HuM7DGUQFGe1bS9sAWsyl/niXs6eX69CtYpw6P7aocX5hih6o+hzi/KdJgtGg4dHBWyo+d6BaqBXr6WizHHGnzkwEE173o+v+BZoOnFiPtyPdFQki2uYNLuHEman/vFxSuTJXiZgl+BD4RR9dlTjnBkGWxB6vrhSQgVf4SCOAaWoX18XK90pKBRf1eQS/nXkENo586yAsjWw3BjOA6foJitYV9ZkGOiwaD4W8SSy2tlHTBR0zx6nKd4KpF+8Ie92V+5rMsAvjxiTVM8kB1eK1yPxZasSlKpQoWs4mYFkwEo+/Droeu8b225fa4WLuUbFt81bL1QZJ1COILrSLEYFMEYm2jm7foP3Nk353XGhDi6bma2fJPZNaym91TrnoeJJgPMRRKs6ZHIJh8KxQNzLosck4Jy+Kly8t+FkadIhbd1RLibg0L20eh/h68NkIwL4j6li7DM+r48D5rk+/Z7DssG8cLvkiIt2zZ/d8q8+bF9mCaT2aMG67tyY3OSdSDQVH1qCa7ElEMS82ETLXtkwjACcMtbzawrOYuqNYGTZQ== krks.gbr@gmail.com"
  ];
  backendPort = "3000";
in
{
  # This sets up networking and filesystems in a way that works with garnix
  # hosting.
  garnix.server.enable = true;

  # This is so we can log in.
  #   - First we enable SSH
  services.openssh.enable = true;
  #   - Then we create a user called "me". You can change it if you like; just
  #     remember to use that user when ssh'ing into the machine.
  users.users.me = {
    # This lets NixOS know this is a "real" user rather than a system user,
    # giving you for example a home directory.
    isNormalUser = true;
    description = "me";
    extraGroups = [ "wheel" "systemd-journal" ];
    openssh.authorizedKeys.keys = sshKeys;
  };
  # This allows you to use `sudo` without a password when ssh'ed into the machine.
  security.sudo.wheelNeedsPassword = false;

  # This specifies what packages are available in your system. You can choose
  # from over 100,000 - search for them here:
  #   https://search.nixos.org/options?channel=24.05
  environment.systemPackages = [
    pkgs.htop
    pkgs.tree
  ];

  # Setting up a systemd unit running the go backend.
  systemd.services.backend = {
    description = "example go backend";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Environment = "PORT=" + backendPort;
      Type = "simple";
      DynamicUser = true;
      ExecStart = lib.getExe self.packages.${pkgs.system}.backend;
    };
  };

  # Configuring `nginx` to do two things:
  #
  # 1. Serve the frontend bundle on /.
  # 2. Proxy to the backend on /api.
  services.nginx =
    {
      # This switches on nginx.
      enable = true;
      # Enabling some good defaults.
      recommendedProxySettings = true;
      recommendedOptimisation = true;
      recommendedGzipSettings = true;
      virtualHosts."default" = {
        # Serving the frontend bundle by default.
        locations."/".root = "${self.packages.${pkgs.system}.frontend-bundle}";
        # Proxying to the backend on /api.
        locations."/api".proxyPass = "http://localhost:${backendPort}/";
      };
    };

  # We open just the http default port in the firewall. SSL termination happens
  # automatically on garnix's side.
  networking.firewall.allowedTCPPorts = [ 80 ];

  # This is currently the only allowed value.
  nixpkgs.hostPlatform = "x86_64-linux";
}
