"""Create a separate Android project; never modify desktop assets or settings."""
import argparse,pathlib,shutil,re,json
parser=argparse.ArgumentParser();parser.add_argument('--output',default='mobile-build/game');args=parser.parse_args()
ROOT=pathlib.Path(__file__).resolve().parents[1];target=(ROOT/args.output).resolve()
if ROOT not in target.parents:raise ValueError('Android staging must stay inside project')
target.mkdir(parents=True,exist_ok=True)
shutil.copytree(ROOT/'game',target,dirs_exist_ok=True,ignore=shutil.ignore_patterns('.godot','*.import','export_credentials.cfg'))
project=(target/'project.godot').read_text(encoding='utf-8-sig')
project=project.replace('config/name="Alderwick — Medieval Town"','config/name="Alderwick Mobile"')
project=project.replace('"process/size_limit": 1024','"process/size_limit": 512')
project=project.replace('window/size/viewport_width=1440','window/size/viewport_width=1280').replace('window/size/viewport_height=900','window/size/viewport_height=720')
project=project.replace('[display]','[display]\nwindow/stretch/mode="canvas_items"\nwindow/handheld/orientation=0')
project+='\n[input_devices]\npointing/emulate_touch_from_mouse=false\npointing/emulate_mouse_from_touch=true\n'
(target/'project.godot').write_text(project,encoding='utf-8')
presets='''[preset.0]
name="Android"
platform="Android"
runnable=true
advanced_options=false
dedicated_server=false
custom_features="mobile_build"
export_filter="all_resources"
include_filter="*.json,*.gdshader"
exclude_filter="*_review.gd,*_review.gd.uid,animals/new/sheep-test_non-commercial*,animals/new/inspection.json,animals/new/walking-rigs.json"
export_path="../../builds/android/Alderwick-Android.apk"
script_export_mode=2

[preset.0.options]
custom_template/debug=""
custom_template/release=""
gradle_build/use_gradle_build=false
architectures/armeabi-v7a=false
architectures/arm64-v8a=true
architectures/x86=false
architectures/x86_64=false
version/code=1
version/name="0.1.0"
package/unique_name="com.elleson.alderwick"
package/name="Alderwick"
package/signed=true
package/app_category=0
package/retain_data_on_uninstall=false
screen/immersive_mode=true
screen/support_small=true
screen/support_normal=true
screen/support_large=true
screen/support_xlarge=true
permissions/internet=true
permissions/record_audio=true
user_data_backup/allow=false
apk_expansion/enable=false
'''
(target/'export_presets.cfg').write_text(presets,encoding='utf-8')
print('ANDROID_PROJECT_PREPARED',target)
