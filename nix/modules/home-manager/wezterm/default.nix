{ inputs, pkgs,... }:

let
  system = pkgs.stdenv.hostPlatform.system;
in
{
  programs.wezterm = {
    enable = false;
    package = inputs.wezterm.packages.${system}.default;
    enableZshIntegration = false;
  };

  xdg.configFile."wezterm/wezterm.lua".text = ''
    local wezterm = require("wezterm")
    local config = wezterm.config_builder()
    local scheme = 'nord'
    local mux = wezterm.mux
    local act = wezterm.action

    local function basename(path)
      return path:match("([^/]+)/*$") or path
    end
    local function file_path_from_uri(uri)
      if not uri then
        return nil
      end
      if type(uri) == "userdata" and uri.file_path then
        return uri.file_path
      end
      local s = tostring(uri)
      local path = s:gsub("^file://[^/]*", "")
      path = path:gsub("%%20", " ")
      return path
    end
    local function git_branch(cwd)
      if not cwd or cwd == "" then
        return nil
      end
      local ok_repo, stdout_repo = wezterm.run_child_process({
        "git",
        "-C",
        cwd,
        "rev-parse",
        "--is-inside-work-tree",
      })
      if not ok_repo or stdout_repo:gsub("%s+", "") ~= "true" then
        return nil
      end
      local ok_branch, stdout_branch = wezterm.run_child_process({
        "git",
        "-C",
        cwd,
        "branch",
        "--show-current",
      })
      if ok_branch then
        local branch = stdout_branch:gsub("%s+$", "")
        if branch ~= "" then
          return branch
        end
      end
      local ok_head, stdout_head = wezterm.run_child_process({
        "git",
        "-C",
        cwd,
        "rev-parse",
        "--short",
        "HEAD",
      })
      if ok_head then
        local head = stdout_head:gsub("%s+$", "")
        if head ~= "" then
          return head
        end
      end
      return nil
    end

    wezterm.on('gui-startup', function(window)
      local tab, pane, window = mux.spawn_window(cmd or {})
      local gui_window = window:gui_window();
      gui_window:maximize()
    end)

    wezterm.on("update-right-status", function(window, pane)
      local cwd_uri = pane:get_current_working_dir()
      local cwd = file_path_from_uri(cwd_uri)
      if not cwd then
        window:set_right_status("")
        return
      end
      local branch = git_branch(cwd)
      if not branch then
        window:set_right_status("")
        return
      end
      branch = string.upper(branch)
      local dir = string.upper(basename(cwd))
      window:set_right_status(wezterm.format({
        { Foreground = { Color = "#5E81AC" } },
        { Text = "" .. dir .. "" },
        { Foreground = { Color = "#5E81AC" } },
        { Text = " [" .. branch .. "]  " },
      }))
    end)

    local TAB_L_SEPARATOR = wezterm.nerdfonts.ple_left_half_circle_thick
    local TAB_R_SEPARATOR = wezterm.nerdfonts.ple_right_half_circle_thick
    wezterm.on("format-tab-title", function(tab, tabs, panes, config, hover, max_width)
      local tab_index = tab.tab_index + 1
      local indicator = ""
      local indicator_foreground = "#2E3440"
      local edge_background = "none"
      local background = "#4C566A"
      local foreground = "#2E3440"
      if tab.is_active then
        indicator_foreground = "#A3BE8C"
        background = "#5E81AC"
        foreground = "#2E3440"
      end

      local edge_foreground = background
      local raw_title = wezterm.truncate_right(tab.active_pane.title, max_width - 4)
      return {
        { Background = { Color = edge_background } },
        { Foreground = { Color = edge_foreground } },
        { Text = TAB_L_SEPARATOR },

        { Background = { Color = background } },
        { Foreground = { Color = indicator_foreground } },
        { Text = indicator },

        { Background = { Color = background } },
        { Foreground = { Color = foreground } },
        { Text = " " .. tab_index .. " " .. string.upper(raw_title) .. " " },

        { Background = { Color = edge_background } },
        { Foreground = { Color = edge_foreground } },
        { Text = TAB_R_SEPARATOR },
      }
    end)

    config.native_macos_fullscreen_mode = false
    -- config.initial_cols = 205
    -- config.initial_rows = 100
    config.color_scheme = scheme
    config.front_end = "WebGpu"
    config.use_ime = true
    config.leader = { key = "'", mods = "CTRL", timeout_milliseconds = 2000 }
    config.default_cursor_style = "BlinkingBlock"
    config.window_decorations = 'RESIZE'
    config.window_padding = { left = '1.5cell', right = '1.5cell', top = '1cell', bottom = '0cell' }
    config.window_background_gradient = {
      colors = { wezterm.get_builtin_color_schemes()[scheme].background }
    }
    config.window_frame = {
      font = require('wezterm').font 'GeistMono Nerd Font Mono',
      font_size = 14,
      inactive_titlebar_bg = "none",
      active_titlebar_bg = "none",
    }
    config.command_palette_bg_color = "rgba(59, 66, 82, 0.9)"
    config.command_palette_fg_color = "rgba(216, 222, 233, 1.0)"
    config.tab_max_width = 16
    config.use_fancy_tab_bar = true
    config.show_tabs_in_tab_bar = true
    config.tab_bar_at_bottom = false
    config.show_close_tab_button_in_tabs = true
    config.show_new_tab_button_in_tab_bar = false
    config.hide_tab_bar_if_only_one_tab = false
    -- config.cursor_blink_rate = 500
    config.cursor_blink_ease_in = 'Constant'
    config.cursor_blink_ease_out = 'Constant'
    config.animation_fps = 120
    config.harfbuzz_features = { 'calt = 0', 'clig = 0', 'liga = 0' }
    config.font_size = 14.6
    config.font = wezterm.font_with_fallback({
      "GeistMono Nerd Font Mono",
      "UDEV Gothic 35NF",
    })
    config.colors = {
      split = "#434C5E",
      tab_bar = {
        background = "none",
        inactive_tab_edge = "none",
      },
    }
    config.inactive_pane_hsb = {
      saturation = 1.0,
      brightness = 1.0,
    }
    config.keys = {
      -- pane splitting
      { key = '"', mods = "LEADER|SHIFT", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },
      { key = "%", mods = "LEADER|SHIFT", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
      -- pane navigation
      { key = "h", mods = "LEADER", action = act.ActivatePaneDirection("Left") },
      { key = "l", mods = "LEADER", action = act.ActivatePaneDirection("Right") },
      { key = "k", mods = "LEADER", action = act.ActivatePaneDirection("Up") },
      { key = "j", mods = "LEADER", action = act.ActivatePaneDirection("Down") },
      { key = "z", mods = "LEADER", action = act.TogglePaneZoomState },
      -- shell word movement
      { key = "LeftArrow", mods = "OPT", action = act.SendKey({ key = "b", mods = "ALT" }) },
      { key = "RightArrow", mods = "OPT", action = act.SendKey({ key = "f", mods = "ALT" }) },
      -- command palette
      { key = "p", mods = "SUPER", action = act.ActivateCommandPalette },
    }
    return config
  '';
}
