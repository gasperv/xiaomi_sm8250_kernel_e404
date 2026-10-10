# AnyKernel3 Ramdisk Mod Script
# osm0sis @ xda-developers
#
# E404R kernel custom installer by 113
# What are you looking for ?

properties() { '
kernel.string=\\ E404R Kernel by Project 113 \\
do.modules=0
do.systemless=1
'; }

devicecheck() {
  local device devicename match product testname vendordevice vendorproduct;
  device=$(getprop ro.product.device 2>/dev/null);
  product=$(getprop ro.build.product 2>/dev/null);
  vendordevice=$(getprop ro.product.vendor.device 2>/dev/null);
  vendorproduct=$(getprop ro.vendor.product.device 2>/dev/null);
  for testname in $(grep 'devicename' anykernel.sh | cut -d= -f2-); do
    for devicename in $device $product $vendordevice $vendorproduct; do
      if [[ "$devicename" == *"$testname"* ]] || [[ "$devicename2" == *"$testname"* ]]; then
        match=1
        break
      fi
    done
  done
  if [[ ! "$match" ]]; then
    abort " " " Unsupported device. Aborting...";
  fi
}

select_option() {
  ui_print " - $1 :"
  ui_print "  (Vol +) $2"
  ui_print "  (Vol -) $3"

  SELECT_RESULT=""
  while true; do
    key_event=$(getevent -qlc 1)
    case "$key_event" in
      *"KEY_VOLUMEUP"*"DOWN"*|*"KEY_VOLUMEUP"*"1"*)
        ui_print "  Selected : $2" " "
        SELECT_RESULT="$2"
        break
        ;;
      *"KEY_VOLUMEDOWN"*"DOWN"*|*"KEY_VOLUMEDOWN"*"1"*)
        ui_print "  Selected : $3" " "
        SELECT_RESULT="$3"
        break
        ;;
    esac
    sleep 0.1
  done
  echo "$SELECT_RESULT"
}

configure_manual() {
  # ROM selection
  select_option "ROM/DTBO Type" "AOSP/CLO" "MIUI/HyperOS"
  rom_sel="$SELECT_RESULT"
  case "$rom_sel" in
    *AOSP*|*CLO*)
      rom="rom_aosp"
      if [[ "$devicename" == "pipa" ]]; then
        dtbo="dtbo_def_pipa"
      else
        dtbo="dtbo_def"
      fi
      ;;
    *MIUI*|*HyperOS*)
      rom="rom_oem"
      if [[ "$devicename" == "pipa" ]]; then
        dtbo="dtbo_oem_pipa"
      else
        dtbo="dtbo_oem"
      fi
      ;;
  esac

  # DTB selection
  select_option "DTB CPU Frequency" "EFFCPU" "Default"
  dtb_sel="$SELECT_RESULT"
  case "$dtb_sel" in
    *EFFCPU*) dtb="dtb_effcpu" ;;
    *) dtb="dtb_def" ;;
  esac

  # Battery profile (Alioth only)
  if [[ "$devicename" == "alioth" ]]; then
    select_option "Battery Profile" "5000mAh" "Default"
    batt_sel="$SELECT_RESULT"
    case "$batt_sel" in
      *5000*) batt="batt_5k" ;;
      *) batt="batt_def" ;;
    esac
  else
    batt="batt_def"
  fi

  ui_print " Manual configuration done !" " "
  sleep 0.5
}

configure_auto() {
  sleep 0.5
  miprops="$(file_getprop /vendor/build.prop "ro.vendor.miui.build.region" 2>/dev/null)"
  if [[ -z "$miprops" ]]; then
    miprops="$(file_getprop /product/etc/build.prop "ro.miui.build.region" 2>/dev/null)"
  fi
  case "$miprops" in
    cn|in|ru|id|eu|tr|tw|gb|global|mx|jp|kr|lm|cl|mi)
      ui_print "--> Miui/HyperOS ROM detected, configuring..."
      rom="rom_oem"
      if [[ "$devicename" == "pipa" ]]; then
        dtbo="dtbo_oem_pipa"
      else
        dtbo="dtbo_oem"
      fi
      ;;
    *)
      ui_print "--> AOSP/CLO ROM detected, configuring..."
      rom="rom_aosp"
      if [[ "$devicename" == "pipa" ]]; then
        dtbo="dtbo_def_pipa"
      else
        dtbo="dtbo_def"
      fi
     ;;
  esac

  sleep 0.5
  if [[ "$ZIPFILE" == *effcpu* || "$ZIPFILE" == *EFFCPU* ]]; then
    ui_print "--> EFFCPUFreq is detected, configuring..."
    dtb="dtb_effcpu"
  else
    ui_print "--> EFFCPUFreq not detected, skipping..."
    dtb="dtb_def"
  fi

  sleep 0.5
  if [[ "$devicename" == "alioth" ]]; then
    if [[ "$ZIPFILE" == *5k* || "$ZIPFILE" == *5K* ]]; then
      ui_print "--> 5K battery profile detected, configuring..."
      batt="batt_5k"
    else
      ui_print "--> Stock Alioth battery profile, configuring..."
      batt="batt_def"
    fi
  else
    batt="batt_def"
  fi

  ui_print " " " Auto configuration done !" " "
  sleep 0.5
}

choose_config_mode() {
  ui_print "--> Select Kernel Configuration :"
  ui_print "  (Vol +) Manual Configuration "
  ui_print "  (Vol -) Auto Configuration "
  ui_print "  ! Timeout in 8 seconds, defaults to Auto"

  local timeout=8
  local start now key_event

  start=$(date +%s)

  while :; do
    key_event=$(timeout 0.2 getevent -qlc 1 2>/dev/null)

    if [ -n "$key_event" ]; then
      if echo "$key_event" | grep -q "KEY_VOLUMEUP"; then
        ui_print "  Selected : Manual Configuration" " "
        configure_manual
        return 0
      fi

      if echo "$key_event" | grep -q "KEY_VOLUMEDOWN"; then
        ui_print "  Selected : Auto Configuration" " "
        configure_auto
        return 0
      fi
    fi

    now=$(date +%s)
    if [ $((now - start)) -ge $timeout ]; then
      ui_print "  ! Timeout reached" " "
      configure_auto
      return 0
    fi
  done
}

#
# Install begins here
# 

devicename=alioth
case "$devicename" in
  munch|alioth|pipa)
    is_slot_device=1;
  ;;
  apollo|lmi)
    is_slot_device=0;
  ;;
esac
case "$devicename" in
  munch)
    devicename2=munchin
  ;;
  alioth)
    devicename2=aliothin
  ;;
  apollo)
    devicename2=apollon
  ;;
esac
block=/dev/block/bootdevice/by-name/boot
ramdisk_compression=auto
patch_vbmeta_flag=auto

. tools/ak3-core.sh

if [[ -f /vendor/OemPorts10T.prop ]] ||
  [[ -f /vendor/etc/init/OemPorts10T.rc ]]; then
  ui_print " ! OPLUS Port ROM by Dandaa NO LONGER SUPPORTED !"
  abort " " Unsupported ROM. Aborting..." "
fi

sleep 0.5
if [[ "$SIDELOAD" == "1" ]]; then
  ui_print " " " ! Sideloading Detected, Overriding to Manual Configuration !"
  configure_manual
else
  choose_config_mode
fi

mv *-Image $home/Image
# Undervolted GPU dtb is opt-in: add -uv to the zip name (e.g. ...-EFFCPU-uv.zip)
case "$(basename "$ZIPFILE")" in
  *[-_][Uu][Vv][-_.]*) gpu_uv=1 ;;
  *) gpu_uv=0 ;;
esac
if [[ $gpu_uv == 1 ]] && ls *-dtb-uv >/dev/null 2>&1; then
  ui_print "--> GPU undervolt (-uv) detected, using undervolted GPU DTB..."
  rm -f *-dtb
  mv *-dtb-uv $home/dtb
else
  ui_print "--> Stock GPU voltages"
  rm -f *-dtb-uv
  mv *-dtb $home/dtb
fi
mv *-dtbo.img $home/dtbo.img

dump_boot

ui_print "--> Applying configuration..."
ui_print " $rom,$dtbo,$dtb,$batt"
patch_cmdline "e404_args" "e404_args=$rom,$dtbo,$dtb,$batt"

write_boot

if [[ $is_slot_device == 1 ]]; then
 ui_print "--> Installing to vendor_boot partition... "
  block=/dev/block/bootdevice/by-name/vendor_boot
  ramdisk_compression=auto
  patch_vbmeta_flag=auto
  reset_ak
  dump_boot
  write_boot
else
  ui_print "--> Installing to boot partition... "
fi

ui_print " " " E404R Kernel @ Project113 "
ui_print " " " --- Install Complete --- "