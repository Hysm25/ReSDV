#!/usr/bin/env python3
"""
extract_assets.py - GOG Vanilla Asset and Data Extractor for ReSDV.
Extracts and converts original Stardew Valley 1.6+ assets directly into user://vanilla_data/
Compatible with CachyOS (AVX-only) and Termux Fedora PRoot (aarch64).
Uses Python standard library only (no pip / external libraries required).
"""

import argparse
import hashlib
import json
import os
import re
import struct
import subprocess
import sys
import zlib

DEFAULT_CONTENT_PATH = "/home/hysm/Games/Stardew Valley/Content"
DEFAULT_USER_DATA = os.path.expanduser("~/.local/share/godot/app_userdata/ReSDV/vanilla_data")

SEASONS = ["spring", "summer", "fall", "winter"]

CATEGORY_MAP = {
    -74: 2,  # SEED
    -75: 3,  # CROP (Vegetable)
    -79: 3,  # CROP (Fruit)
    -80: 3,  # CROP (Flower)
    -81: 6,  # FORAGE
    -2: 4,   # MINERAL (Gem)
    -12: 4,  # MINERAL
    -4: 5,   # FISH
    -7: 7,   # COOKING
    -8: 8,   # CRAFTING
    -19: 9,  # FERTILIZER
    -96: 10, # RING
    -98: 11, # WEAPON
    -97: 12, # BOOTS
    -99: 1,  # TOOL
}

class ByteReader:
    def __init__(self, data: bytes):
        self.data = data
        self.pos = 0

    def read_7bit(self) -> int:
        res = 0
        shift = 0
        while True:
            byte = self.data[self.pos]
            self.pos += 1
            res |= (byte & 0x7F) << shift
            if not (byte & 0x80):
                break
            shift += 7
        return res

    def read_str(self) -> str:
        slen = self.read_7bit()
        s = self.data[self.pos : self.pos + slen].decode("utf-8", errors="replace")
        self.pos += slen
        return s

    def read_i32(self) -> int:
        val = struct.unpack_from("<i", self.data, self.pos)[0]
        self.pos += 4
        return val

    def read_u32(self) -> int:
        val = struct.unpack_from("<I", self.data, self.pos)[0]
        self.pos += 4
        return val

    def read_f32(self) -> float:
        val = struct.unpack_from("<f", self.data, self.pos)[0]
        self.pos += 4
        return val

    def read_f64(self) -> float:
        val = struct.unpack_from("<d", self.data, self.pos)[0]
        self.pos += 8
        return val

    def read_bool(self) -> bool:
        val = self.data[self.pos] != 0
        self.pos += 1
        return val


def compute_md5(file_path: str) -> str:
    h = hashlib.md5()
    with open(file_path, "rb") as f:
        while chunk := f.read(65536):
            h.update(chunk)
    return h.hexdigest().upper()


def validate_hashes(content_dir: str, target_files: list[str]) -> bool:
    hash_file = os.path.join(content_dir, "ContentHashes.json")
    if not os.path.exists(hash_file):
        print(f"[Warning] ContentHashes.json not found in {content_dir}. Skipping hash check.")
        return True

    print(f"[Validator] Reading {hash_file}...")
    with open(hash_file, "r", encoding="utf-8") as f:
        hashes = json.load(f)

    all_valid = True
    for rel_path in target_files:
        expected = hashes.get(rel_path)
        actual_path = os.path.join(content_dir, rel_path)
        if not os.path.exists(actual_path):
            print(f"[Validator] ERROR: Missing file {actual_path}")
            all_valid = False
            continue

        if expected:
            actual_md5 = compute_md5(actual_path)
            if actual_md5 == expected.upper():
                print(f"[Validator] OK: {rel_path} matches hash {expected}")
            else:
                print(f"[Validator] MISMATCH: {rel_path} (expected {expected}, got {actual_md5})")
                all_valid = False
        else:
            print(f"[Validator] Note: No hash recorded for {rel_path}")

    return all_valid


def ensure_decompressor(importer_dir: str) -> str:
    binary_path = os.path.join(importer_dir, "xnb_decompress")
    if os.path.exists(binary_path) and os.access(binary_path, os.X_OK):
        return binary_path

    print("[Decompressor] Compiling native xnb_decompress...")
    c_src = os.path.join(importer_dir, "xnb_decompress.c")
    lzx_src = os.path.join(importer_dir, "lzx.c")
    cmd = ["gcc", "-O2", c_src, lzx_src, "-o", binary_path]
    subprocess.check_call(cmd)
    return binary_path


def decompress_xnb(decompressor: str, xnb_path: str, dec_path: str) -> None:
    os.makedirs(os.path.dirname(dec_path), exist_ok=True)
    subprocess.check_call([decompressor, xnb_path, dec_path])


def write_png(width: int, height: int, rgba_data: bytes, out_path: str) -> None:
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    png = bytearray(b"\x89PNG\r\n\x1a\n")

    # IHDR
    ihdr_data = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    ihdr_crc = zlib.crc32(b"IHDR" + ihdr_data)
    png += struct.pack(">I", 13) + b"IHDR" + ihdr_data + struct.pack(">I", ihdr_crc)

    # IDAT (filter byte 0 prefix per scanline)
    scanlines = bytearray()
    pitch = width * 4
    for y in range(height):
        scanlines.append(0)
        scanlines.extend(rgba_data[y * pitch : (y + 1) * pitch])

    compressed_idat = zlib.compress(scanlines, 6)
    idat_crc = zlib.crc32(b"IDAT" + compressed_idat)
    png += struct.pack(">I", len(compressed_idat)) + b"IDAT" + compressed_idat + struct.pack(">I", idat_crc)

    # IEND
    iend_crc = zlib.crc32(b"IEND")
    png += struct.pack(">I", 0) + b"IEND" + struct.pack(">I", iend_crc)

    with open(out_path, "wb") as f:
        f.write(png)


def extract_texture(dec_path: str, png_path: str) -> bool:
    with open(dec_path, "rb") as f:
        data = f.read()

    r = ByteReader(data)
    num_readers = r.read_7bit()
    for _ in range(num_readers):
        r.read_str()
        r.pos += 4
    r.read_7bit()  # shared count
    r.read_7bit()  # type id

    surface_format, width, height, mip_count = struct.unpack_from("<IIII", data, r.pos)
    r.pos += 16
    data_size = struct.unpack_from("<I", data, r.pos)[0]
    r.pos += 4

    raw_rgba = data[r.pos : r.pos + data_size]
    write_png(width, height, raw_rgba, png_path)
    print(f"[Texture] Converted {os.path.basename(dec_path)} -> {png_path} ({width}x{height})")
    return True


def extract_strings_objects(dec_path: str) -> dict[str, str]:
    with open(dec_path, "rb") as f:
        data = f.read()

    r = ByteReader(data)
    num_readers = r.read_7bit()
    for _ in range(num_readers):
        r.read_str()
        r.pos += 4
    r.read_7bit()
    r.read_7bit()
    count = r.read_u32()

    strings_map: dict[str, str] = {}
    for _ in range(count):
        r.read_7bit()  # key tid
        k = r.read_str()
        r.read_7bit()  # val tid
        v = r.read_str()
        strings_map[k] = v

    print(f"[Strings] Parsed {len(strings_map)} entries from Strings/Objects.")
    return strings_map


def resolve_token(token: str, strings_map: dict[str, str], fallback: str) -> str:
    if not token:
        return fallback
    m = re.match(r"\[LocalizedText [^:]+:([^\]]+)\]", token)
    if m:
        key = m.group(1)
        if key in strings_map:
            return strings_map[key]
    return token.replace("[LocalizedText ", "").replace("]", "")


def read_optional_str(r: ByteReader) -> str:
    tid = r.read_7bit()
    if tid == 0:
        return ""
    return r.read_str()


def extract_crops(dec_path: str) -> dict[str, dict]:
    with open(dec_path, "rb") as f:
        b = f.read()

    r = ByteReader(b)
    num_readers = r.read_7bit()
    for _ in range(num_readers):
        r.read_str()
        r.pos += 4
    r.read_7bit()
    r.read_7bit()
    count = r.read_u32()

    crops: dict[str, dict] = {}

    for _ in range(count):
        r.read_7bit()
        key = r.read_str()
        r.read_7bit()  # val tid

        # 1. Seasons
        r.read_7bit()
        s_cnt = r.read_u32()
        seasons = [SEASONS[r.read_i32()] for _ in range(s_cnt)]

        # 2. DaysInPhase
        r.read_7bit()
        d_cnt = r.read_u32()
        days = [r.read_i32() for _ in range(d_cnt)]

        # 3. RegrowDays
        regrow = r.read_i32()
        # 4. IsRaised
        is_raised = r.read_bool()
        # 5. IsPaddyCrop
        is_paddy = r.read_bool()
        # 6. NeedsWatering
        needs_water = r.read_bool()

        # 7. PlantableLocationRules
        plr_tid = r.read_7bit()
        rules: list[dict] = []
        if plr_tid != 0:
            plr_cnt = r.read_u32()
            for _ in range(plr_cnt):
                r.read_7bit()  # rule reflective reader tid
                rule_id = read_optional_str(r)
                cond = read_optional_str(r)
                ctx = r.read_i32()
                res = r.read_i32()
                msg = read_optional_str(r)
                rules.append({"id": rule_id, "condition": cond, "context": ctx, "result": res, "message": msg})

        # 8. HarvestItemId
        harvest_id = read_optional_str(r)

        # 9. HarvestMinStack
        h_min = r.read_i32()
        # 10. HarvestMaxStack
        h_max = r.read_i32()
        # 11. HarvestMaxIncreasePerFarmingLevel
        h_inc = r.read_f32()
        # 12. ExtraHarvestChance
        extra_chance = r.read_f64()
        # 13. HarvestMethod
        harvest_method = r.read_i32()

        # 14. HarvestMinQuality
        min_q = r.read_i32()

        # 15. HarvestMaxQuality (Nullable<int>)
        has_max_q = r.read_bool()
        max_q = r.read_i32() if has_max_q else None

        # 16. TintColors (List<string>)
        tint_tid = r.read_7bit()
        tints: list[str] = []
        if tint_tid != 0:
            t_cnt = r.read_u32()
            for _ in range(t_cnt):
                r.read_7bit()
                tints.append(r.read_str())

        # 17. Texture
        tex = read_optional_str(r)
        if not tex:
            tex = "TileSheets/crops"

        # 18. SpriteIndex
        sprite_idx = r.read_i32()
        # 19. CountForMonoculture
        mono = r.read_bool()
        # 20. CountForPolyculture
        poly = r.read_bool()

        # 21. CustomFields (Dictionary<string, string>)
        cf_tid = r.read_7bit()
        custom_fields: dict[str, str] = {}
        if cf_tid != 0:
            cf_cnt = r.read_u32()
            for _ in range(cf_cnt):
                r.read_7bit()
                ck = r.read_str()
                r.read_7bit()
                cv = r.read_str()
                custom_fields[ck] = cv

        crops[key] = {
            "id": key,
            "seed_item_id": key,
            "harvest_item_id": harvest_id,
            "growth_phase_days": days,
            "seasons": seasons,
            "regrow_after_harvest_days": regrow,
            "is_trellis_crop": is_raised,
            "is_paddy_crop": is_paddy,
            "needs_watering": needs_water,
            "min_harvest": h_min,
            "max_harvest": h_max,
            "max_harvest_increase_per_farming_level": h_inc,
            "chance_for_extra_crops": extra_chance,
            "harvest_method": harvest_method,
            "harvest_min_quality": min_q,
            "harvest_max_quality": max_q,
            "texture": tex.replace("\\", "/"),
            "sprite_index": sprite_idx,
            "tint_colors": tints,
            "plantable_rules": rules,
            "count_for_monoculture": mono,
            "count_for_polyculture": poly,
        }

    print(f"[Crops] Parsed {len(crops)} crops from Data/Crops.")
    return crops


def extract_objects(dec_path: str, strings_map: dict[str, str]) -> dict[str, dict]:
    with open(dec_path, "rb") as f:
        b = f.read()

    # Pattern matches the core sequence of every ObjectData in Stardew Valley 1.6
    pattern = rb"\x02([\x01-\x20][a-zA-Z0-9_\(\)\-\.\x27 ]+)\x03\x02([\x01-\x30][a-zA-Z0-9_\(\)\-\.\x27 ]+)\x02([\x01-\x7f][^\x00]+?)\x02([\x01-\x7f][^\x00]+?)\x02([\x01-\x20][a-zA-Z0-9_\-]+)"
    matches = list(re.finditer(pattern, b))

    objects: dict[str, dict] = {}

    for m in matches:
        key = m.group(1)[1:].decode("latin1", errors="replace")
        name = m.group(2)[1:].decode("latin1", errors="replace")
        disp_token = m.group(3)[1:].decode("latin1", errors="replace")
        desc_token = m.group(4)[1:].decode("latin1", errors="replace")
        otype = m.group(5)[1:].decode("latin1", errors="replace")

        pos = m.end()
        cat, price = struct.unpack_from("<ii", b, pos)
        pos += 8

        tex_tid = b[pos]
        pos += 1
        if tex_tid == 2:
            slen = b[pos]
            pos += 1
            tex = b[pos : pos + slen].decode("latin1", errors="replace")
            pos += slen
        else:
            tex = "Maps/springobjects"

        sprite_idx = struct.unpack_from("<i", b, pos)[0]
        pos += 4
        color_overlay = b[pos] != 0
        pos += 1
        edibility = struct.unpack_from("<i", b, pos)[0]
        pos += 4
        is_drink = b[pos] != 0
        pos += 1

        disp_name = resolve_token(disp_token, strings_map, name)
        description = resolve_token(desc_token, strings_map, "")
        godot_category = CATEGORY_MAP.get(cat, 0)

        objects[key] = {
            "id": key,
            "name": disp_name if disp_name else name,
            "internal_name": name,
            "description": description,
            "category": godot_category,
            "vanilla_category": cat,
            "price": price,
            "edibility": edibility,
            "max_stack": 999,
            "texture": tex.replace("\\", "/"),
            "sprite_index": sprite_idx,
            "is_drink": is_drink,
            "can_be_given_as_gift": True,
            "can_be_trashed": True,
        }

    print(f"[Objects] Parsed {len(objects)} objects from Data/Objects.")
    return objects


def main() -> int:
    parser = argparse.ArgumentParser(description="Extract vanilla Stardew Valley assets into user://vanilla_data/")
    parser.add_argument("--content-dir", default=DEFAULT_CONTENT_PATH, help="Path to Stardew Valley Content directory")
    parser.add_argument("--output-dir", default=DEFAULT_USER_DATA, help="Output destination for extracted assets")
    args = parser.parse_args()

    content_dir = os.path.abspath(args.content_dir)
    output_dir = os.path.abspath(args.output_dir)
    script_dir = os.path.dirname(os.path.abspath(__file__))
    temp_dir = os.path.join(output_dir, ".temp")

    print(f"=== ReSDV Vanilla Asset Pipeline ===")
    print(f"Source: {content_dir}")
    print(f"Destination: {output_dir}")

    if not os.path.isdir(content_dir):
        print(f"Error: Content directory does not exist: {content_dir}")
        return 1

    target_files = [
        "Data/Objects.xnb",
        "Data/Crops.xnb",
        "Strings/Objects.xnb",
        "TileSheets/crops.xnb",
        "TileSheets/tools.xnb",
        "Maps/springobjects.xnb",
    ]

    # Step 1: Validate MD5 hashes
    if not validate_hashes(content_dir, target_files):
        print("[Warning] Content hash mismatch detected. Proceeding anyway...")

    # Step 2: Native decompressor
    decompressor = ensure_decompressor(script_dir)

    os.makedirs(output_dir, exist_ok=True)
    os.makedirs(temp_dir, exist_ok=True)

    # Step 3: Decompress XNBs
    dec_files: dict[str, str] = {}
    for rel in target_files:
        src = os.path.join(content_dir, rel)
        dst = os.path.join(temp_dir, rel + ".dec")
        print(f"[Decompress] {rel} -> {dst}")
        decompress_xnb(decompressor, src, dst)
        dec_files[rel] = dst

    # Step 4: Extract Strings
    strings_map = extract_strings_objects(dec_files["Strings/Objects.xnb"])
    with open(os.path.join(output_dir, "StringsObjects.json"), "w", encoding="utf-8") as f:
        json.dump(strings_map, f, indent=2, ensure_ascii=False)

    # Step 5: Extract Crops
    crops_map = extract_crops(dec_files["Data/Crops.xnb"])
    crops_json_path = os.path.join(output_dir, "Crops.json")
    with open(crops_json_path, "w", encoding="utf-8") as f:
        json.dump(crops_map, f, indent=2, ensure_ascii=False)

    # Step 6: Extract Objects
    objects_map = extract_objects(dec_files["Data/Objects.xnb"], strings_map)
    objects_json_path = os.path.join(output_dir, "Objects.json")
    with open(objects_json_path, "w", encoding="utf-8") as f:
        json.dump(objects_map, f, indent=2, ensure_ascii=False)

    # Duplicate to Data/ subfolder for flexible ContentRegistry resolution
    data_dir = os.path.join(output_dir, "Data")
    os.makedirs(data_dir, exist_ok=True)
    with open(os.path.join(data_dir, "Crops.json"), "w", encoding="utf-8") as f:
        json.dump(crops_map, f, indent=2, ensure_ascii=False)
    with open(os.path.join(data_dir, "Objects.json"), "w", encoding="utf-8") as f:
        json.dump(objects_map, f, indent=2, ensure_ascii=False)

    # Step 7: Extract Textures
    extract_texture(dec_files["TileSheets/crops.xnb"], os.path.join(output_dir, "TileSheets/crops.png"))
    extract_texture(dec_files["TileSheets/tools.xnb"], os.path.join(output_dir, "TileSheets/tools.png"))
    extract_texture(dec_files["Maps/springobjects.xnb"], os.path.join(output_dir, "Maps/springobjects.png"))

    # Step 8: Cleanup temp
    import shutil
    shutil.rmtree(temp_dir, ignore_errors=True)

    print(f"[Done] Extraction complete! Vanilla assets written to: {output_dir}")
    print(f"  - Objects: {len(objects_map)} in Objects.json")
    print(f"  - Crops: {len(crops_map)} in Crops.json")
    print(f"  - Textures: crops.png, tools.png, springobjects.png")
    return 0


if __name__ == "__main__":
    sys.exit(main())
