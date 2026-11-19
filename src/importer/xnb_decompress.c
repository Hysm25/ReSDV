/*
 * xnb_decompress.c - Clean-room LZX/Raw XNB Decompressor for ReSDV
 * Compatible with CachyOS (x86_64, AVX-only) and Termux Fedora PRoot (aarch64).
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include "lzx.h"

static uint32_t read_u32le(const uint8_t *buf) {
    return (uint32_t)buf[0] |
           ((uint32_t)buf[1] << 8) |
           ((uint32_t)buf[2] << 16) |
           ((uint32_t)buf[3] << 24);
}

int main(int argc, char *argv[]) {
    if (argc < 3) {
        fprintf(stderr, "Usage: %s <input.xnb> <output.dec>\n", argv[0]);
        return 1;
    }

    FILE *f_in = fopen(argv[1], "rb");
    if (!f_in) {
        fprintf(stderr, "Error: cannot open input file '%s'\n", argv[1]);
        return 1;
    }

    uint8_t header[14];
    if (fread(header, 1, 14, f_in) != 14) {
        fprintf(stderr, "Error: failed to read 14-byte XNB header\n");
        fclose(f_in);
        return 1;
    }

    if (header[0] != 'X' || header[1] != 'N' || header[2] != 'B') {
        fprintf(stderr, "Error: '%s' is not a valid XNB file (missing magic)\n", argv[1]);
        fclose(f_in);
        return 1;
    }

    uint8_t flags = header[5];
    uint32_t comp_size = read_u32le(header + 6);
    uint32_t dec_size = read_u32le(header + 10);

    FILE *f_out = fopen(argv[2], "wb");
    if (!f_out) {
        fprintf(stderr, "Error: cannot open output file '%s'\n", argv[2]);
        fclose(f_in);
        return 1;
    }

    /* Uncompressed XNB (flag 0x80 not set) */
    if (!(flags & 0x80)) {
        uint8_t buffer[8192];
        size_t bytes_read;
        while ((bytes_read = fread(buffer, 1, sizeof(buffer), f_in)) > 0) {
            fwrite(buffer, 1, bytes_read, f_out);
        }
        fclose(f_in);
        fclose(f_out);
        return 0;
    }

    /* LZX Compressed XNB (flag 0x80 set) */
    struct LZXstate *strm = LZXinit(16);
    if (!strm) {
        fprintf(stderr, "Error: failed to initialize LZX decoder with window 16\n");
        fclose(f_in);
        fclose(f_out);
        return 1;
    }

    uint8_t dst[0x8000];
    uint8_t src[0x8000];
    uint32_t total_decompressed = 0;

    while (total_decompressed < dec_size) {
        int hi = fgetc(f_in);
        if (hi == EOF) {
            break;
        }

        int dst_size = 0;
        int src_size = 0;

        if (hi == 0xFF) {
            int hi_dst = fgetc(f_in);
            int lo_dst = fgetc(f_in);
            dst_size = (hi_dst << 8) | lo_dst;

            int hi_src = fgetc(f_in);
            int lo_src = fgetc(f_in);
            src_size = (hi_src << 8) | lo_src;
        } else {
            dst_size = 0x8000;
            int lo = fgetc(f_in);
            src_size = (hi << 8) | lo;
        }

        if (src_size <= 0 || dst_size <= 0) {
            break;
        }

        if (fread(src, 1, src_size, f_in) != (size_t)src_size) {
            fprintf(stderr, "Error: unexpected EOF reading compressed block (%d bytes)\n", src_size);
            break;
        }

        int ret = LZXdecompress(strm, src, dst, src_size, dst_size);
        if (ret != DECR_OK) {
            fprintf(stderr, "Error: LZXdecompress returned error code %d\n", ret);
            break;
        }

        fwrite(dst, 1, dst_size, f_out);
        total_decompressed += (uint32_t)dst_size;
    }

    LZXteardown(strm);
    fclose(f_in);
    fclose(f_out);

    if (total_decompressed != dec_size) {
        fprintf(stderr, "Warning: Decompressed %u bytes, expected %u bytes\n", total_decompressed, dec_size);
    }

    return 0;
}
