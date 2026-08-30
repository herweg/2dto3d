import json, struct, sys

def extract(path, out_path):
    with open(path, 'rb') as f:
        data = f.read()
    magic, version, length = struct.unpack_from('<III', data, 0)
    offset = 12
    json_chunk = None
    bin_chunk = None
    while offset < length:
        chunk_len, chunk_type = struct.unpack_from('<II', data, offset)
        offset += 8
        chunk_data = data[offset:offset+chunk_len]
        if chunk_type == 0x4E4F534A:
            json_chunk = json.loads(chunk_data.decode('utf-8'))
        elif chunk_type == 0x004E4942:
            bin_chunk = chunk_data
        offset += chunk_len
        if chunk_len % 4 != 0:
            offset += 4 - (chunk_len % 4)

    img = json_chunk['images'][0]
    bv = json_chunk['bufferViews'][img['bufferView']]
    start = bv.get('byteOffset', 0)
    end = start + bv['byteLength']
    img_bytes = bin_chunk[start:end]
    with open(out_path, 'wb') as f:
        f.write(img_bytes)
    print(f"wrote {out_path}, {len(img_bytes)/1024:.1f} KB")

if __name__ == '__main__':
    extract(sys.argv[1], sys.argv[2])
