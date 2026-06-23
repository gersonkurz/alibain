/*
 * smoke_zip.c — minimal consumer that proves alibain's archive.dll can READ
 * a zip archive (and, for deflate entries, that the vendored zlib path works).
 *
 * Consumes the DLL: LIBARCHIVE_STATIC is NOT defined, so __LA_DECL = dllimport.
 * Usage: smoke_zip <archive.zip>
 * Exit 0 only if every entry is listed and its data fully decompresses.
 */
#include <archive.h>
#include <archive_entry.h>
#include <stdio.h>
#include <stdint.h>

int main(int argc, char **argv)
{
	if (argc < 2) {
		fprintf(stderr, "usage: %s <archive>\n", argv[0]);
		return 2;
	}

	struct archive *a = archive_read_new();
	archive_read_support_format_all(a);
	archive_read_support_filter_all(a);

	if (archive_read_open_filename(a, argv[1], 65536) != ARCHIVE_OK) {
		fprintf(stderr, "open failed: %s\n", archive_error_string(a));
		return 1;
	}

	int entries = 0;
	uint64_t total_bytes = 0;
	struct archive_entry *entry;
	int r;
	while ((r = archive_read_next_header(a, &entry)) == ARCHIVE_OK) {
		const char *name = archive_entry_pathname(entry);
		la_int64_t size = archive_entry_size(entry);
		entries++;

		/* Force decompression of the whole entry. */
		char buf[16384];
		la_ssize_t n;
		uint64_t entry_bytes = 0;
		while ((n = archive_read_data(a, buf, sizeof buf)) > 0)
			entry_bytes += (uint64_t)n;
		if (n < 0) {
			fprintf(stderr, "read data failed for '%s': %s\n",
			    name, archive_error_string(a));
			return 1;
		}
		total_bytes += entry_bytes;
		printf("  %-40s %10llu bytes\n", name,
		    (unsigned long long)entry_bytes);
	}
	if (r != ARCHIVE_EOF) {
		fprintf(stderr, "header iteration failed: %s\n",
		    archive_error_string(a));
		return 1;
	}

	archive_read_free(a);
	printf("OK: %d entr%s, %llu bytes decompressed\n",
	    entries, entries == 1 ? "y" : "ies",
	    (unsigned long long)total_bytes);
	return entries > 0 ? 0 : 1;
}
