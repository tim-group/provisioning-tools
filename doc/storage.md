# Storage
## Provisioning tools config
On the VM host machine (where provisioning tools is installed) you must provide some storage configuration. This tells things what types of storage are available on this host and tells provisioning tools how those types of storage map to real physical storage

To continue you'll need to know what storage you have available for you VM's and a name for each type of storage you wish to make available.

### entries in storage in /etc/provision/config.yaml
The simplest entry for storage in the provisioning tools config would look something like this
```yaml
storage:
  type/name:
    arch: a storage architecture
    options:
      storage_architecture_specific_option1: value
      storage_architecture_specific_option2: value2
```
#### Storage types
You can define as many storage types as you like. Each storage type is actually just a name given to a particular type of storage so that it can be referenced by other things.

#### Storage architectures
The storage architecture must be one of the storage architectures provided by provisioning-tools. The architectures currently available are as follows:
##### LVM
An existing LVM Volume Group in which provisioning-tools may create LVM Logical Volumes for a particular guests storage.
##### Image
An existing directory in which provisioning-tools may create image files for a particular guests storage.

#### Storage options
Storage options are different depending on which architecture a particular type of storage is configured with. Available options for each of the currently supported storage architectures follows:
##### LVM
  - vg - The name of the volume group that this storage type can use to create logical volumes in
##### Image
  - image_path - The path to the directory in which this storage type can use to create image files in

### Example
This specific host has a 2 disk RAID1 providing approximately 200GB of free space. We would like to be able to use this space for the root filesystem of each of our guests to live on. The most sensible place for the images to live is /var/local/images so that we stick with convention. We may as well call this storage type 'os'.

So here is what our storage config would look like:
```yaml
storage:
  os:
    arch: Image
    options:
      image_path: /var/local/images
```
We then added a 6 disk RAID10 to the machine to provide a faster storage type on which we want any extra data a guest would have to live. We've configured this array to be an LVM Physical Volume and created an LVM Volume Group there called 'disk2'. It makes sense for us to call this storage type 'data'

In addition to the previous example, we now add the following to the storage config:
```yaml
  data:
    arch: LVM
    options:
      vg: disk2
```
That's it. We now have two storage types available for our guests to use.


## Storage spec
Each guest to be created by provisioning-tools needs to provide a storage config within its specification so that provisioning-tools can create the correct storage for the guest.

### basic storage spec
A simple entry for a storage spec would look something like this (note, all keys are ruby symbols, but the examples do not show the '!ruby/sym' part of the key name):
```yaml
storage:
  mount_point:
    type: the storage type on which this storage is to be configured
    size: the size of the storage
```

  - **mount_point**:
    - sub section containing all configuration for this mount point
    - it should be the literal mount point within the guests filesystem. / or /mnt/data would be valid examples
    - **type**: < storage type name >
      - one of the storage types defined on the host. os or data would be valid examples if we had the previously mentioned storage types in existence.
    - **size**: < size >
      - size in the format <number><units>, for example 25G would mean 25 Gigabytes.
    - **chmod**: <permissions>
      - change the permissions of the root of the mount point
      - permissions in a format compatible with the chmod command

### All storage spec options
There are numerous things that can be provided within the storage spec for each mount point, they are as follows:
#### Persistence
  - mount_point:
    - sub section, as above, included here purely to make formatting correct
    - **persistent**: < true | false >
      - Whether a specific piece of storage should be deleted or not when a guest is removed. true would keep the storage, false would mean that it was removed on guest clean up
    - **persistence_options**:
     - sub section with the following options
       - **on_storage_not_found**: < create_new | raise_error >
         - create_new will go ahead and create the storage if it's not found
         - raise_error will raise an error if the storage does not exist
#### Initialisation
  - mount_point:
    - sub section, as above, included here purely to make formatting correct
    - **prepare**:
      - sub section with the following options
      - **method**: < image | format >
        - image will initialise this storage from some sort of image file
        - format will initialise this storage by creating a new filesystem
      - **options**:
        - sub section with the following options
        - **resize**: < true | false >
          - whether to resize the resultant filesystem after initialisation -  method **image** only
          - ie. if the image you create from is only 3GB, but your storage is 25GB, should the filesystem be expanded to fill all available space
        - **path**: < /path/to/image.file | http(s)?://some.url.tld/path/to/image.file >
          - the path used to obtain the image file used to initialise the filesystem -  method **image** only
        - **type**: < filesystem type >
          - the filesystem type used when creating the new filesystem -  method **format** only
          - In theory this could be anything that has an mkfs.<type> command associated with it. Only tested with ext3 and ext4 currently
        - **create_in_fstab**: < true | false >
          - whether this mount point should end up in the fstab of the guest. Mostly introduced to support windows where we can't edit an fstab!
        - **virtio**: < true | false >
          - whether this mount point's underlying storage should use libvirts virtio drivers or not. Mostly introduced to support older Windows images where adding in virtio driver support wasn't easy
        - **shrink_after_unmount**: < true | false >
          - whether this mount point should have its filesystem, partitions, etc. shrunk to the minimum size possible after initialisation etc. Mostly introduced to shrink filesystems to then use as gold images.
        - **create_guest_lvm**: < true | false >
          - whether to create lvm PV (and VG and LV) within the underlying block device before creating the filesystem (on the newly created LV)
          - only useable when method is format and creating a new filesystem
        - **guest_lvm_pv_size**: < size >
          - size in the format <number><units>, for example 25G would mean 25 Gigabytes
          - can only be used when create_guest_lvm is set to true
          - must be equal to or larger than mount point's size setting.
        - **usage_type**: < usage_type >
          - The data provided to mkfs.extX -T argument

