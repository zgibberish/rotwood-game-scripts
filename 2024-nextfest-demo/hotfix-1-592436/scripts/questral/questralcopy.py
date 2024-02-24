import pprint
import re
import shutil
from pathlib import Path

src_root = Path("c:/code/gln/data/scripts/")
dst_root = Path("c:/code/FromTheForge/data/scripts/")


def crlf_all(dest_dir):
    for fpath in dest_dir.glob("**/*.lua"):
        with fpath.open("r") as f:
            text = f.read()
        with fpath.open("w") as f:
            f.write(text)


def copy_files(src_glob, dest_dir):
    for fpath in src_glob:
        dest = dest_dir / fpath.name.lower()
        print(fpath, "->", dest)
        shutil.copy(fpath, dest)


def check_requires(dest_dir):
    q_modules = {f.stem: f for f in (dst_root / "questral").glob("**/*.lua")}
    q_modules["lpeg"] = "native"
    q_modules["coro"] = "C:/code/FromTheForge/data/scripts/util/coro.lua"

    q_modules["agentutil"] = "ignore"

    missing = {}

    for f in dest_dir.glob("**/*.lua"):
        with f.open("r") as f:
            for line in f:
                req = re.search(r"""\brequire\b.*["'](\S*)["']""", line)
                if req:
                    module_path = req.group(1)
                    mod_name = re.sub(r"^.+\.", "", module_path)
                    if not mod_name:
                        print("Unhandled:", line)
                    if mod_name not in q_modules and not mod_name.startswith("cmp"):
                        missing[mod_name] = module_path

    pprint.pprint(
        ["Missing {}      Fullpath {}".format(k, v) for k, v in missing.items()]
    )
    pprint.pprint(missing)


#
# Text processing
#


def process_files(dest_dir, process_fn):
    for fpath in dest_dir.glob("**/*.lua"):
        with fpath.open("r") as f:
            text = f.read()
        text = process_fn(text)
        with fpath.open("w") as f:
            f.write(text)


def _convert_module_match(match):
    mod_path = match.group(2).lower()
    return match.group(1) + mod_path.replace("/", ".")


def clean_requires(dest_dir):
    util = dst_root / "questral/util/"
    util_modules = [f.stem for f in util.glob("*.lua")]
    root_modules = [f.stem for f in (dst_root / "questral").glob("*.lua")]

    def fn(text):
        text = re.sub(r"""(\brequire\b ")(\S+)""", _convert_module_match, text)
        for m in util_modules:
            text = text.replace('require "util.' + m, 'require "questral.util.' + m)
        for m in root_modules:
            text = text.replace('require "sim.' + m, 'require "questral.' + m)
            text = text.replace('require "%s"' % m, 'require "questral.%s"' % m)
        return text

    return process_files(dest_dir, fn)


def _convert_class_match(match):
    parent = match.group(3)
    if parent:
        return "Class({}, function(self, ...) self:init(...) end)".format(parent)
    return "Class(function(self, ...) self:init(...) end)"


def convert_classes(text):
    text = re.sub(r"""Class\(\s*("\S+")(, (.*))?\s*\)""", _convert_class_match, text)
    text = re.sub(r":mixin\(",                           r":add_mixin(",       text)
    return text


def convert_table_lib(text):
    # Convert gln's table module to ours. Will produce some undefined values
    # but they're easy to fix.
    text = re.sub("table.arrayadd", "table.appendarrays", text)
    text = re.sub("table.arraypick", "krandom.PickFromArray", text)
    text = re.sub("table.arrayremove", "table.removearrayvalue", text)
    text = re.sub("table.copykeys", "table.getkeys", text)
    text = re.sub("table.enum", "Enum", text)
    text = re.sub("table.shallowcopy", "shallowcopy", text)
    text = re.sub("table.shuffle", "krandom.Shuffle_NeedsAttention", text)
    text = re.sub("table.sorted_pairs", "iterator.sorted_pairs", text)
    text = re.sub(r"table.isEnumType\(\s*(\w+)\s*\)", r"Enum.IsEnumType(\1)", text)
    text = re.sub(r"table.isEnum\(\s*(\w+), ([^, )]+)\s*\)", r"\2:Contains(\1)", text)
    # text = re.sub("table.binfind",          "table.", text)
    # text = re.sub("table.binsert",          "table.", text)
    # text = re.sub("table.binsert_unique",   "table.", text)
    # text = re.sub("table.insert_unique",    "table.", text)
    # text = re.sub("table.stable_sort",      "table.", text)
    return text


def convert_class_lib(text):
    # Convert gln's class module to ours.
    # We're using these ones:
    # * Class.getTerminalSubclasses
    # * Class.isClass
    # * Class.isInstance

    text = re.sub(r"Class.isInstance\(\s*(\w+), (\w+)\s*\)", r"\2.is_instance(\1)", text)
    text = re.sub(r"self == self._class",                    r"self:is_class()",    text)

    # text = re.sub(r"Class.RegisterClass\(\s*(\w+), (\w+)\s*\)",         r"\2.RegisterClass(\1)",         text)
    # text = re.sub(r"Class.findMethod\(\s*(\w+), (\w+)\s*\)",            r"\2.findMethod(\1)",            text)
    # text = re.sub(r"Class.getSubclasses\(\s*(\w+), (\w+)\s*\)",         r"\2.getSubclasses(\1)",         text)
    # text = re.sub(r"Class.getTerminalSubclasses\(\s*(\w+), (\w+)\s*\)", r"\2.getTerminalSubclasses(\1)", text)
    text = re.sub(r"Class.hasMixin\(\s*(\w+), (\w+)\s*\)",              r"\2:has_mixin(\1)",             text)
    # text = re.sub(r"Class.hasSubclasses\(\s*(\w+), (\w+)\s*\)",         r"\2.hasSubclasses(\1)",         text)
    # text = re.sub(r"Class.isClass\(\s*(\w+), (\w+)\s*\)",               r"\2.isClass(\1)",               text)
    # text = re.sub(r"Class.isMethod\(\s*(\w+), (\w+)\s*\)",              r"\2.isMethod(\1)",              text)
    # text = re.sub(r"Class.reload\(\s*(\w+)\s*\)",                       r"\1.reload()",                  text)
    return text


def convert_string_lib(text):
    # Convert gln's string module to ours. Will produce some missing requires
    # but they're easy to fix.
    text = re.sub(r"(\w+):split\(([^(]+)\)", r"kstring.split_pattern(\1, \2)", text)
    text = re.sub(r"(\w+):split\(\)", r"kstring.split_pattern(\1)", text)
    text = re.sub(r"string.rstr\b", r"table.inspect", text)

    return text


def convert_other(text):
    # Convert gln's fe to ours.
    text = re.sub(r"self:GetFE\(\):InsertScreen", r"TheFrontEnd:PushScreen", text)
    text = re.sub(r"self.convoplayer:GetFE\(\):InsertScreen", r"TheFrontEnd:PushScreen", text)

    # Use Talk instead of Dialog(ue)
    text = re.sub(r":Dialog\(", r":Talk(", text)
    return text

def convert_string_constants(text):
    text = re.sub(r'\s?"DIALOG.DIALOG_', r'"TALK.TALK_', text)
    text = re.sub(r'\s?"DIALOG.',        r'"TALK.',      text)
    return text

def convert_inspector(text):
    text = re.sub("ui.Style_", "ui.Col.", text)
    text = re.sub(r"(0x[0-9a-fA-F]{8})", r"HexToRGB(\1)", text)
    text = re.sub(r"TheGame:FE\(\)", r"TheFrontEnd", text)
    text = re.sub(r"TheGame:GetInput\(\)", r"TheInput", text)
    return text


do_it_all = True

if do_it_all:
    q_root = dst_root / "questral/"
    q_util = dst_root / "questral/util/"

    copy_files((src_root / "content/").glob("emotes.lua"), dst_root / "questral/ref")

    copy_files((src_root / "sim/").glob("Convo*"), q_root)
    copy_files((src_root / "sim/").glob("Quest*"), q_root)
    copy_files((src_root / "sim/").glob("Agent.lua"), q_root)
    copy_files((src_root / "sim/").glob("ScenarioTrigger*"), q_root)
    copy_files(src_root.glob("*Content*.lua"), q_root)
    copy_files(src_root.glob("Localization.lua"), q_root)
    copy_files(src_root.glob("Quip*.lua"), q_root)
    copy_files(src_root.glob("GameNode.lua"), q_root)

    copy_files((src_root / "util/").glob("DialogParser.lua"), q_util)
    copy_files((src_root / "util/").glob("ExpressionParser.lua"), q_util)
    copy_files((src_root / "util/").glob("StringFormatter.lua"), q_util)
    copy_files((src_root / "util/").glob("Translator.lua"), q_util)
    copy_files((src_root / "util/").glob("string.lua"), q_util)
    copy_files((src_root / "util/").glob("loc*.lua"), q_util)
    copy_files((src_root / "util/").glob("TagSet.lua"), q_util)
    copy_files((src_root / "util/").glob("Validator.lua"), q_util)

    shutil.copy(src_root / "debug/inspectors/DebugAgent.lua", dst_root / "dbui/debug_agent.lua")
    shutil.copy(src_root / "debug/inspectors/DebugQuest.lua", dst_root / "dbui/debug_quest.lua")
    shutil.copy(src_root / "debug/inspectors/DebugQuestManager.lua", dst_root / "dbui/debug_questmanager.lua")
    crlf_all(dst_root / "dbui")

    shutil.copy(src_root / "sim/Entity.lua", q_root / "questralactor.lua")

    crlf_all(q_root)


q_root = dst_root / "questral/"
#~ q_root = dst_root / "dbui"

if do_it_all:
    check_requires(q_root)


if do_it_all:
    clean_requires(q_root)


if do_it_all:
    process_files(q_root, convert_classes)
    process_files(q_root, convert_table_lib)
    process_files(q_root, convert_class_lib)
    process_files(q_root, convert_string_lib)
    process_files(q_root, convert_other)
    process_files(q_root, convert_string_constants)

if do_it_all:
    db_root = dst_root / "dbui"
    process_files(db_root, convert_inspector)
    check_requires(q_root)
    clean_requires(q_root)
    process_files(q_root, convert_classes)
    process_files(q_root, convert_table_lib)
    process_files(q_root, convert_class_lib)
    process_files(q_root, convert_string_lib)
    process_files(q_root, convert_other)
    process_files(q_root, convert_string_constants)


# Entity -> components.questralactor
# :\<\V\(FillOutQuipTags\|GetQuipID\|FindChildByClass\|IsCastInQuest\|GetChildren\|RemoveFromQuest\|GetQuests\|DetachChild\|GetComponent\|GetType\|AddComponent\|RemoveComponent\|Fill\|GetQuestOfType\|AttachChild\|AddToQuest\)\>
