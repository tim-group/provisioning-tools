require 'provisioning-tools/provision/storage/commands'

module Provision::Storage::Tasks
  include Provision::Storage::Commands

  private

  def create_partition_task(name, device, fstype, for_lvm = false)
    run_task(name, "create partition table on #{device}",
             :task => lambda do
               create_partition(device, fstype, for_lvm)
             end)
  end

  def create_partition_device_nodes_task(name, device)
    run_task(name, "create partition device nodes for #{device}",
             :task => lambda do
               kpartxa_new(device)
             end,
             :cleanup => lambda do
               kpartxd_new(device)
             end)
  end

  def remove_partition_device_nodes_task(name, device)
    run_task(name, "remove partition device nodes for #{device}",
             :task => lambda do
               kpartxd_new(device)
             end,
             :remove_cleanup => "create partition device nodes for #{device}"
            )
  end

  def create_lvm_lv_task(name, lv_name, vg_name, lv_size, with_cleanup = true)
    task_hash = {
      :task => lambda { create_lvm_lv(lv_name, vg_name, lv_size) }
    }
    task_hash[:cleanup] = lambda { remove_lvm_lv(lv_name, vg_name) } if with_cleanup

    run_task(name, "create a new LVM LV #{lv_name} in VG #{vg_name}", task_hash)
  end

  def initialise_vg_in_guest_lvm_task(name, device, vg_name)
    run_task(name, "setup #{device} as a new LVM PV",
             :task => lambda { create_lvm_pv(device) },
             :cleanup => lambda { force_remove_lvm_pv(device) }
            )
    run_task(name, "create an LVM VG called #{vg_name} on PV #{device}",
             :task => lambda { create_lvm_vg(vg_name, device) },
             :cleanup => lambda { disable_lvm_vg(vg_name) }
            )
  end

  def disable_lvm_vg_task(name, vg_name)
    run_task(name, "disable the LVM VG #{vg_name}",
             :task => lambda { disable_lvm_vg(vg_name) }
            )
  end
end
