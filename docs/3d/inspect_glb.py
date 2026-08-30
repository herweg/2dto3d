import json, struct, sys

def inspect(path):
    with open(path, 'rb') as f:
        data = f.read()
    magic, version, length = struct.unpack_from('<III', data, 0)
    assert magic == 0x46546C67, "not a glb"
    offset = 12
    json_chunk = None
    bin_len = 0
    n_images_embedded = 0
    image_sizes = []
    while offset < length:
        chunk_len, chunk_type = struct.unpack_from('<II', data, offset)
        offset += 8
        chunk_data = data[offset:offset+chunk_len]
        if chunk_type == 0x4E4F534A:  # JSON
            json_chunk = json.loads(chunk_data.decode('utf-8'))
        elif chunk_type == 0x004E4942:  # BIN
            bin_len = len(chunk_data)
        offset += chunk_len
        # pad to 4 bytes
        if chunk_len % 4 != 0:
            offset += 4 - (chunk_len % 4)

    print(f"=== {path} ===")
    print(f"file size: {len(data)/1024/1024:.2f} MB, BIN chunk: {bin_len/1024/1024:.2f} MB")

    accessors = json_chunk.get('accessors', [])
    meshes = json_chunk.get('meshes', [])
    materials = json_chunk.get('materials', [])
    images = json_chunk.get('images', [])
    textures = json_chunk.get('textures', [])
    animations = json_chunk.get('animations', [])
    skins = json_chunk.get('skins', [])
    nodes = json_chunk.get('nodes', [])
    buffer_views = json_chunk.get('bufferViews', [])

    total_tris = 0
    total_verts = 0
    for m in meshes:
        for prim in m.get('primitives', []):
            mode = prim.get('mode', 4)
            pos_acc_idx = prim.get('attributes', {}).get('POSITION')
            if pos_acc_idx is not None:
                total_verts += accessors[pos_acc_idx]['count']
            idx_acc_idx = prim.get('indices')
            if idx_acc_idx is not None:
                cnt = accessors[idx_acc_idx]['count']
                if mode == 4:  # TRIANGLES
                    total_tris += cnt // 3

    print(f"meshes: {len(meshes)}, materials: {len(materials)}, images: {len(images)}, textures: {len(textures)}")
    print(f"total vertices (approx, sum over primitives): {total_verts}")
    print(f"total triangles (approx, sum over primitives): {total_tris}")
    print(f"animations: {len(animations)}, skins: {len(skins)}, nodes: {len(nodes)}")

    # image sizes via bufferView lengths (compressed size on disk, not decoded resolution)
    for i, img in enumerate(images):
        bv_idx = img.get('bufferView')
        mime = img.get('mimeType', '?')
        if bv_idx is not None:
            bv = buffer_views[bv_idx]
            sz = bv.get('byteLength', 0)
            print(f"  image[{i}]: mime={mime}, encoded size={sz/1024:.1f} KB")
    for anim in animations:
        print(f"  animation name: {anim.get('name')}, channels: {len(anim.get('channels', []))}")

if __name__ == '__main__':
    for p in sys.argv[1:]:
        inspect(p)
        print()
