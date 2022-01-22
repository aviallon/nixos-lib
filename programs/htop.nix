{config, pkgs, lib, ...}:
{
  programs.htop.enable = true;
  programs.htop.settings = {
#    fields=0 48 17 18 38 39 40 2 46 47 49 1
#    sort_key=46
#    sort_direction=-1
#    tree_sort_key=0
#    tree_sort_direction=1
    hide_kernel_threads = true;
    hide_userland_threads = true;
    shadow_other_users = 0;
    show_thread_names = true;
    show_program_path = 0;
    highlight_base_name = true;
    highlight_deleted_exe = true;
    highlight_megabytes = true;
    highlight_threads = true;
    highlight_changes = 0;
    highlight_changes_delay_secs = 5;
    find_comm_in_cmdline = true;
    strip_exe_from_cmdline = true;
    show_merged_command = true;
    tree_view = true;
    #tree_view_always_by_pid=0
    #all_branches_collapsed=0
    header_margin = 0;
    detailed_cpu_time = true;
    cpu_count_from_one = 0;
    show_cpu_usage = true;
    show_cpu_frequency = true;
    show_cpu_temperature = true;
    degree_fahrenheit = 0;
    update_process_names = 0;
    account_guest_in_cpu_meter = true;
    color_scheme = 0;
    enable_mouse = true;
    delay = 10;
    hide_function_bar = 0;
    header_layout = "two_50_50";
    column_meters_0 = [ "AllCPUs" "Memory" "Swap" ];
    column_meter_modes_0 = [ 1 1 1 ];
    column_meters_1 = [ "Tasks" "LoadAverage" "Uptime" "DiskIO" "NetworkIO" ];
    column_meter_modes_1 = [ 2 2 2 2 2 ];
  };
}
