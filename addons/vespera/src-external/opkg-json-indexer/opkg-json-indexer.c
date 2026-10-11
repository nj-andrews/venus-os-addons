#define _DEFAULT_SOURCE
#define _POSIX_C_SOURCE 200809L

#include <ctype.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#define MAX_LINE 2048
#define MAX_FIELD 256
#define MAX_FIELDS 50
#define MAX_FEEDS 256
#define OPKG_JSON_INDEXER_VERSION "1.1.0"

static const char *const builtin_feeds[] = {
	"vespera",
	NULL
};

typedef struct {
	char key[MAX_FIELD];
	char value[MAX_LINE];
} Field;

typedef struct {
	Field fields[MAX_FIELDS];
	int field_count;
} Package;

typedef struct {
	char name[MAX_FIELD];
	char version[MAX_FIELD];
} InstalledEntry;

typedef struct {
	InstalledEntry *items;
	size_t count;
	size_t capacity;
} InstalledMap;

typedef struct {
	char name[MAX_FIELD];
	char url[MAX_LINE];
} FeedEntry;

typedef struct {
	char lists_dir[PATH_MAX];
	char info_dir[PATH_MAX];
	char status_file[PATH_MAX];
	FeedEntry feeds[MAX_FEEDS];
	int feed_count;
} OpkgConfig;

typedef enum {
	UPDATE_ALL = 0,
	UPDATE_FEEDS = 1,
	UPDATE_PACKAGES = 2,
	UPDATE_NONE = 3
} UpdateMode;

static void json_escape_print(FILE *fp, const char *str)
{
	if (!str) {
		return;
	}

	fputc('"', fp);
	while (*str) {
		switch (*str) {
			case '"':
				fputs("\\\"", fp);
				break;
			case '\\':
				fputs("\\\\", fp);
				break;
			case '\n':
				fputs("\\n", fp);
				break;
			case '\r':
				fputs("\\r", fp);
				break;
			case '\t':
				fputs("\\t", fp);
				break;
			default:
				if ((unsigned char)*str < 32) {
					fprintf(fp, "\\u%04x", (unsigned char)*str);
				} else {
					fputc(*str, fp);
				}
		}
		str++;
	}
	fputc('"', fp);
}

static void trim(char *str)
{
	if (!str) {
		return;
	}

	char *start = str;
	while (*start && isspace((unsigned char)*start)) {
		start++;
	}

	if (*start == '\0') {
		str[0] = '\0';
		return;
	}

	char *end = start + strlen(start) - 1;
	while (end >= start && isspace((unsigned char)*end)) {
		end--;
	}
	*(end + 1) = '\0';
	memmove(str, start, strlen(start) + 1);
}

static void normalize_field_name(const char *input, char *output, size_t outlen)
{
	size_t i = 0;
	for (; input[i] && i < outlen - 1; i++) {
		char c = input[i];
		if (c == '-' || c == ' ') {
			output[i] = '_';
		} else {
			output[i] = (char)tolower((unsigned char)c);
		}
	}
	output[i] = '\0';
}

static size_t parse_base_version_parts(const char *version,
								   unsigned long *parts,
								   size_t max_parts,
								   const char **suffix_start)
{
	const char *p = version ? version : "";
	size_t count = 0;

	while (*p && isspace((unsigned char)*p)) {
		p++;
	}

	if (!isdigit((unsigned char)*p)) {
		if (suffix_start) {
			*suffix_start = p;
		}
		return 0;
	}

	while (*p && isdigit((unsigned char)*p)) {
		char *end = NULL;
		unsigned long value = strtoul(p, &end, 10);
		if (count < max_parts) {
			parts[count++] = value;
		}
		p = end;

		if (*p == '.' && isdigit((unsigned char)p[1])) {
			p++;
			continue;
		}
		break;
	}

	if (suffix_start) {
		*suffix_start = p;
	}
	return count;
}

static size_t parse_suffix_numbers(const char *suffix, unsigned long *parts, size_t max_parts)
{
	const char *p = suffix ? suffix : "";
	size_t count = 0;

	while (*p) {
		if (!isdigit((unsigned char)*p)) {
			p++;
			continue;
		}

		char *end = NULL;
		unsigned long value = strtoul(p, &end, 10);
		if (count < max_parts) {
			parts[count++] = value;
		}
		p = end;
	}

	return count;
}

static int compare_numeric_parts(const unsigned long *a,
								 size_t a_count,
								 const unsigned long *b,
								 size_t b_count)
{
	size_t max_count = a_count > b_count ? a_count : b_count;

	for (size_t i = 0; i < max_count; ++i) {
		unsigned long av = i < a_count ? a[i] : 0;
		unsigned long bv = i < b_count ? b[i] : 0;
		if (av > bv) {
			return 1;
		}
		if (av < bv) {
			return -1;
		}
	}

	return 0;
}

static int version_greater_than(const char *candidate, const char *installed)
{
	unsigned long base_candidate[32] = {0};
	unsigned long base_installed[32] = {0};
	unsigned long suffix_candidate[32] = {0};
	unsigned long suffix_installed[32] = {0};
	const char *suffix_candidate_start = NULL;
	const char *suffix_installed_start = NULL;

	size_t base_candidate_count = parse_base_version_parts(candidate,
												   base_candidate,
												   sizeof(base_candidate) / sizeof(base_candidate[0]),
												   &suffix_candidate_start);
	size_t base_installed_count = parse_base_version_parts(installed,
												   base_installed,
												   sizeof(base_installed) / sizeof(base_installed[0]),
												   &suffix_installed_start);
	int base_cmp = compare_numeric_parts(base_candidate,
									 base_candidate_count,
									 base_installed,
									 base_installed_count);
	if (base_cmp > 0) {
		return 1;
	}
	if (base_cmp < 0) {
		return 0;
	}

	size_t suffix_candidate_count = parse_suffix_numbers(suffix_candidate_start,
												 suffix_candidate,
												 sizeof(suffix_candidate) / sizeof(suffix_candidate[0]));
	size_t suffix_installed_count = parse_suffix_numbers(suffix_installed_start,
												 suffix_installed,
												 sizeof(suffix_installed) / sizeof(suffix_installed[0]));
	return compare_numeric_parts(suffix_candidate,
								 suffix_candidate_count,
								 suffix_installed,
								 suffix_installed_count) > 0;
}

static void split_version_info(const char *version,
							   char *base_out,
							   size_t base_out_len,
							   char *suffix_out,
							   size_t suffix_out_len)
{
	unsigned long ignored_parts[32] = {0};
	const char *suffix_start = NULL;

	if (!base_out || base_out_len == 0 || !suffix_out || suffix_out_len == 0) {
		return;
	}

	base_out[0] = '\0';
	suffix_out[0] = '\0';

	if (!version || version[0] == '\0') {
		return;
	}

	parse_base_version_parts(version,
						 ignored_parts,
						 sizeof(ignored_parts) / sizeof(ignored_parts[0]),
						 &suffix_start);

	if (!suffix_start || suffix_start <= version) {
		snprintf(base_out, base_out_len, "%s", version);
		return;
	}

	size_t base_len = (size_t)(suffix_start - version);
	if (base_len >= base_out_len) {
		base_len = base_out_len - 1;
	}
	memcpy(base_out, version, base_len);
	base_out[base_len] = '\0';

	if (*suffix_start != '\0') {
		snprintf(suffix_out, suffix_out_len, "%s", suffix_start);
	}
}

static int append_installed_entry(InstalledMap *map, const char *name, const char *version)
{
	if (!map || !name) {
		return 0;
	}

	if (map->count == map->capacity) {
		size_t new_capacity = map->capacity == 0 ? 64 : map->capacity * 2;
		InstalledEntry *new_items = (InstalledEntry *)realloc(map->items, new_capacity * sizeof(*new_items));
		if (!new_items) {
			return 0;
		}
		map->items = new_items;
		map->capacity = new_capacity;
	}

	snprintf(map->items[map->count].name, sizeof(map->items[map->count].name), "%s", name);
	snprintf(map->items[map->count].version, sizeof(map->items[map->count].version), "%s", version ? version : "");
	map->count++;
	return 1;
}

static const char *lookup_installed_version(const InstalledMap *map, const char *name)
{
	if (!map || !name) {
		return "";
	}

	for (size_t i = 0; i < map->count; ++i) {
		if (strcmp(map->items[i].name, name) == 0) {
			return map->items[i].version;
		}
	}

	return "";
}

static void free_installed_map(InstalledMap *map)
{
	if (!map) {
		return;
	}

	free(map->items);
	map->items = NULL;
	map->count = 0;
	map->capacity = 0;
}

static int parse_installed_status(const char *status_file, InstalledMap *map)
{
	FILE *fp = fopen(status_file, "r");
	if (!fp) {
		return 0;
	}

	char line[MAX_LINE];
	char package[MAX_FIELD] = "";
	char version[MAX_FIELD] = "";
	char status[MAX_LINE] = "";

	while (fgets(line, sizeof(line), fp)) {
		line[strcspn(line, "\n")] = '\0';

		if (line[0] == '\0') {
			if (package[0] != '\0' && strstr(status, "installed") != NULL) {
				if (!append_installed_entry(map, package, version)) {
					fclose(fp);
					return 0;
				}
			}
			package[0] = '\0';
			version[0] = '\0';
			status[0] = '\0';
			continue;
		}

		char *colon = strchr(line, ':');
		if (!colon) {
			continue;
		}

		*colon = '\0';
		char *key = line;
		char *value = colon + 1;
		trim(key);
		trim(value);

		if (strcmp(key, "Package") == 0) {
			snprintf(package, sizeof(package), "%s", value);
		} else if (strcmp(key, "Version") == 0) {
			snprintf(version, sizeof(version), "%s", value);
		} else if (strcmp(key, "Status") == 0) {
			snprintf(status, sizeof(status), "%s", value);
		}
	}

	if (package[0] != '\0' && strstr(status, "installed") != NULL) {
		if (!append_installed_entry(map, package, version)) {
			fclose(fp);
			return 0;
		}
	}

	fclose(fp);
	return 1;
}

static int feed_is_builtin(const char *name)
{
	if (!name) {
		return 0;
	}

	for (int i = 0; builtin_feeds[i]; ++i) {
		if (strcmp(name, builtin_feeds[i]) == 0) {
			return 1;
		}
	}

	return 0;
}

static int parse_opkg_config(const char *config_path, OpkgConfig *cfg)
{
	FILE *fp = fopen(config_path, "r");
	if (!fp) {
		fprintf(stderr, "Error: cannot read config: %s\n", config_path);
		return 0;
	}

	memset(cfg, 0, sizeof(*cfg));

	char line[MAX_LINE];
	while (fgets(line, sizeof(line), fp)) {
		line[strcspn(line, "\n")] = '\0';
		trim(line);

		if (!line[0] || line[0] == '#') {
			continue;
		}

		char token1[MAX_FIELD] = "";
		char token2[MAX_FIELD] = "";
		char token3[MAX_LINE] = "";

		if (sscanf(line, "%255s %255s %2047s", token1, token2, token3) != 3) {
			continue;
		}

		if (strcmp(token1, "option") == 0) {
			if (strcmp(token2, "lists_dir") == 0) {
				snprintf(cfg->lists_dir, sizeof(cfg->lists_dir), "%s", token3);
			} else if (strcmp(token2, "info_dir") == 0) {
				snprintf(cfg->info_dir, sizeof(cfg->info_dir), "%s", token3);
			} else if (strcmp(token2, "status_file") == 0) {
				snprintf(cfg->status_file, sizeof(cfg->status_file), "%s", token3);
			}
			continue;
		}

		if ((strcmp(token1, "src/gz") == 0 || strcmp(token1, "src") == 0) && cfg->feed_count < MAX_FEEDS) {
			snprintf(cfg->feeds[cfg->feed_count].name, sizeof(cfg->feeds[cfg->feed_count].name), "%s", token2);
			snprintf(cfg->feeds[cfg->feed_count].url, sizeof(cfg->feeds[cfg->feed_count].url), "%s", token3);
			cfg->feed_count++;
		}
	}

	fclose(fp);

	if (cfg->lists_dir[0] == '\0') {
		fprintf(stderr, "Error: missing option lists_dir in config\n");
		return 0;
	}
	if (cfg->info_dir[0] == '\0') {
		fprintf(stderr, "Error: missing option info_dir in config\n");
		return 0;
	}
	if (cfg->status_file[0] == '\0') {
		fprintf(stderr, "Error: missing option status_file in config\n");
		return 0;
	}

	return 1;
}

static void read_dbus_key_name(const char *info_dir, const char *package_name, char *out)
{
	char path[PATH_MAX];
	FILE *fp;

	if (!out) {
		return;
	}

	out[0] = '\0';
	if (!info_dir || !info_dir[0] || !package_name || !package_name[0]) {
		return;
	}

	if (snprintf(path, sizeof(path), "%s/%s.dbus-name", info_dir, package_name) >= (int)sizeof(path)) {
		return;
	}

	fp = fopen(path, "r");
	if (!fp) {
		return;
	}

	if (fgets(out, MAX_FIELD, fp)) {
		out[strcspn(out, "\n")] = '\0';
		trim(out);
	}
	fclose(fp);
}

static void flush_package_json(const Package *pkg,
					   const char *feed_name,
					   FILE *out_json,
					   int *first_item,
					   const InstalledMap *installed_map,
					   const char *info_dir)
{
	if (!pkg || pkg->field_count <= 0) {
		return;
	}

	const char *package_name = NULL;
	const char *package_version = "";
	const char *installed_version = "";
	const char *available_version = "";
	const char *field_name = "";
	char dbus_key_name[MAX_FIELD] = "";
	char installed_version_base[MAX_FIELD] = "";
	char installed_version_suffix[MAX_FIELD] = "";
	char available_version_base[MAX_FIELD] = "";
	char available_version_suffix[MAX_FIELD] = "";
	int first_field = 1;

	if (!*first_item) {
		fputs(",", out_json);
	}
	fputs("{", out_json);

	for (int i = 0; i < pkg->field_count; i++) {
		field_name = pkg->fields[i].key;
		if (strcmp(field_name, "package") == 0) {
			field_name = "packageName";
			package_name = pkg->fields[i].value;
		} else if (strcmp(field_name, "version") == 0) {
			package_version = pkg->fields[i].value;
			continue;
		}

		if (!first_field) {
			fputs(",", out_json);
		}
		first_field = 0;
		fprintf(out_json, "\"%s\":", field_name);
		json_escape_print(out_json, pkg->fields[i].value);
	}

	if (feed_name) {
		if (!first_field) {
			fputs(",", out_json);
		}
		fputs("\"feed\":", out_json);
		json_escape_print(out_json, feed_name);
		first_field = 0;
	}

	first_field = 0;

	if (installed_map) {
		installed_version = lookup_installed_version(installed_map, package_name);
		if (installed_version[0] != '\0') {
			read_dbus_key_name(info_dir, package_name, dbus_key_name);
		}

		split_version_info(installed_version,
						   installed_version_base,
						   sizeof(installed_version_base),
						   installed_version_suffix,
						   sizeof(installed_version_suffix));

		if (!first_field) {
			fputs(",", out_json);
		}
		fputs("\"installedVersion\":", out_json);
		json_escape_print(out_json, installed_version_base);
		fputs(",\"installedVersionSuffix\":", out_json);
		json_escape_print(out_json, installed_version_suffix);
		first_field = 0;

		if (installed_version[0] != '\0') {
			available_version = version_greater_than(package_version, installed_version)
				? package_version
				: "";
		} else {
			available_version = package_version;
		}

		if (package_version[0] == '\0') {
			available_version = "";
		}
	}

	if (dbus_key_name[0] != '\0') {
		if (!first_field) {
			fputs(",", out_json);
		}
		fputs("\"dbusKeyName\":", out_json);
		json_escape_print(out_json, dbus_key_name);
		first_field = 0;
	}

	split_version_info(available_version,
					   available_version_base,
					   sizeof(available_version_base),
					   available_version_suffix,
					   sizeof(available_version_suffix));

	if (!first_field) {
		fputs(",", out_json);
	}
	fputs("\"availableVersion\":", out_json);
	json_escape_print(out_json, available_version_base);
	fputs(",\"availableVersionSuffix\":", out_json);
	json_escape_print(out_json, available_version_suffix);

	fputs("}", out_json);
	*first_item = 0;
}

static int parse_stanza_file(const char *filepath,
						 const char *feed_name,
						 FILE *out_json,
						 int *first_item,
						 const InstalledMap *installed_map,
						 const char *info_dir,
						 const char *const *allowed_fields,
						 int allowed_count)
{
	FILE *fp = fopen(filepath, "r");
	if (!fp) {
		return 0;
	}

	char line[MAX_LINE];
	Package pkg;
	int last_kept_index = -1;
	memset(&pkg, 0, sizeof(pkg));

	while (fgets(line, sizeof(line), fp)) {
		line[strcspn(line, "\n")] = '\0';

		if (strlen(line) == 0) {
			flush_package_json(&pkg, feed_name, out_json, first_item, installed_map, info_dir);
			memset(&pkg, 0, sizeof(pkg));
			last_kept_index = -1;
			continue;
		}

		if (line[0] == ' ' && last_kept_index >= 0) {
			char *value = line;
			while (*value && isspace((unsigned char)*value)) {
				value++;
			}

			if (strstr(pkg.fields[last_kept_index].value, value) != NULL) {
				continue;
			}

			size_t cur_len = strlen(pkg.fields[last_kept_index].value);
			size_t value_len = strlen(value);
			if (cur_len < (MAX_LINE - 1) && value_len > 0) {
				char *dest = pkg.fields[last_kept_index].value;
				size_t pos = cur_len;

				if (pos > 0 && pos < (MAX_LINE - 1)) {
					dest[pos++] = ' ';
				}

				if (pos < (MAX_LINE - 1)) {
					size_t copy_len = value_len;
					size_t avail = (MAX_LINE - 1) - pos;
					if (copy_len > avail) {
						copy_len = avail;
					}
					memcpy(dest + pos, value, copy_len);
					pos += copy_len;
					dest[pos] = '\0';
				}
			}
			continue;
		}

		char *colon = strchr(line, ':');
		if (!colon) {
			continue;
		}

		*colon = '\0';
		char *key = line;
		char *value = colon + 1;
		char normalized_key[MAX_FIELD];

		trim(key);
		trim(value);
		normalize_field_name(key, normalized_key, sizeof(normalized_key));

		int allowed = 0;
		for (int j = 0; j < allowed_count; j++) {
			if (strcmp(normalized_key, allowed_fields[j]) == 0) {
				allowed = 1;
				break;
			}
		}

		if (!allowed) {
			last_kept_index = -1;
			continue;
		}

		if (pkg.field_count < MAX_FIELDS) {
			snprintf(pkg.fields[pkg.field_count].key,
					 sizeof(pkg.fields[pkg.field_count].key),
					 "%s",
					 normalized_key);
			snprintf(pkg.fields[pkg.field_count].value,
					 sizeof(pkg.fields[pkg.field_count].value),
					 "%s",
					 value);
			last_kept_index = pkg.field_count;
			pkg.field_count++;
		}
	}

	flush_package_json(&pkg, feed_name, out_json, first_item, installed_map, info_dir);
	fclose(fp);
	return 1;
}

static int write_feeds_json(const char *output_file, const OpkgConfig *cfg)
{
	FILE *out = fopen(output_file, "w");
	if (!out) {
		fprintf(stderr, "Error: cannot write %s\n", output_file);
		return 0;
	}

	fputs("[", out);
	for (int i = 0; i < cfg->feed_count; ++i) {
		if (i > 0) {
			fputs(",", out);
		}

		fputs("{\"name\":", out);
		json_escape_print(out, cfg->feeds[i].name);
		fputs(",\"url\":", out);
		json_escape_print(out, cfg->feeds[i].url);
		fprintf(out, ",\"builtin\":%s}", feed_is_builtin(cfg->feeds[i].name) ? "true" : "false");
	}
	fputs("]\n", out);

	fclose(out);
	return 1;
}

static int write_packages_json(const char *output_file, const OpkgConfig *cfg)
{
	const char *allowed_fields[] = {"package", "description", "version", "size"};
	const int allowed_count = (int)(sizeof(allowed_fields) / sizeof(allowed_fields[0]));

	InstalledMap installed = {0};
	if (!parse_installed_status(cfg->status_file, &installed)) {
		installed.items = NULL;
		installed.count = 0;
		installed.capacity = 0;
	}

	FILE *out = fopen(output_file, "w");
	if (!out) {
		fprintf(stderr, "Error: cannot write %s\n", output_file);
		free_installed_map(&installed);
		return 0;
	}

	fputs("[", out);
	int first_item = 1;

	for (int i = 0; i < cfg->feed_count; ++i) {
		char filepath[PATH_MAX];
		size_t base_len = strlen(cfg->lists_dir);
		size_t name_len = strnlen(cfg->feeds[i].name, MAX_FIELD);

		if (base_len + 1 + name_len >= sizeof(filepath)) {
			continue;
		}

		memcpy(filepath, cfg->lists_dir, base_len);
		filepath[base_len] = '/';
		memcpy(filepath + base_len + 1, cfg->feeds[i].name, name_len);
		filepath[base_len + 1 + name_len] = '\0';

		struct stat file_st;
		if (stat(filepath, &file_st) != 0 || !S_ISREG(file_st.st_mode)) {
			continue;
		}

		parse_stanza_file(filepath,
					 cfg->feeds[i].name,
					 out,
					 &first_item,
					 &installed,
					 cfg->info_dir,
					 allowed_fields,
					 allowed_count);
	}

	fputs("]\n", out);
	fclose(out);
	free_installed_map(&installed);
	return 1;
}

static int get_executable_dir(char *out, size_t out_len)
{
	if (!out || out_len == 0) {
		return 0;
	}

	char exe_path[PATH_MAX];
	ssize_t n = readlink("/proc/self/exe", exe_path, sizeof(exe_path) - 1);
	if (n <= 0) {
		return 0;
	}
	exe_path[n] = '\0';

	char *slash = strrchr(exe_path, '/');
	if (!slash) {
		return 0;
	}

	*slash = '\0';
	if (snprintf(out, out_len, "%s", exe_path) >= (int)out_len) {
		return 0;
	}

	return 1;
}

static void print_usage(const char *program)
{
	fprintf(stderr, "Usage: %s %s <opkg.conf> [output_dir] [--update=all|feeds|packages]\n", program, OPKG_JSON_INDEXER_VERSION);
	fprintf(stderr, "  <opkg.conf>    Path to the opkg configuration file\n");
	fprintf(stderr, "  [output_dir]   Optional output directory for feeds.json and packages.json\n");
	fprintf(stderr, "  [--update=..]  Optional update mode: all, feeds, or packages\n");
}

static int parse_update_mode(const char *arg, UpdateMode *mode)
{
	const char *prefix = "--update=";
	size_t prefix_len = strlen(prefix);

	if (strncmp(arg, prefix, prefix_len) != 0) {
		return 0;
	}

	const char *value = arg + prefix_len;
	if (strcmp(value, "all") == 0) {
		*mode = UPDATE_ALL;
		return 1;
	}
	if (strcmp(value, "feeds") == 0) {
		*mode = UPDATE_FEEDS;
		return 1;
	}
	if (strcmp(value, "packages") == 0) {
		*mode = UPDATE_PACKAGES;
		return 1;
	}
	if (strcmp(value, "none") == 0) {
		*mode = UPDATE_NONE;
		return 1;
	}

	return 0;
}

int main(int argc, char **argv) {
	/* Input arguments:
	 *   argv[1] = opkg config file
	 *   argv[2] = optional output directory, unless it starts with "--"
	 *   argv[2..] or argv[3..] = optional --update=all|feeds|packages flags
	 */
	if (argc < 2) {
		print_usage(argv[0]);
		return 1;
	}

	const char *config_path = argv[1];
	const char *output_dir_arg = NULL;
	UpdateMode update_mode = UPDATE_ALL;
	int arg_index = 2;

	if (arg_index < argc && strncmp(argv[arg_index], "--", 2) != 0) {
		output_dir_arg = argv[arg_index];
		arg_index++;
	}

	for (int i = arg_index; i < argc; ++i) {
		if (!parse_update_mode(argv[i], &update_mode)) {
			print_usage(argv[0]);
			return 1;
		}
	}

	OpkgConfig config;
	if (!parse_opkg_config(config_path, &config)) {
		return 1;
	}

	if (update_mode == UPDATE_NONE) {
		return 0;
	}

	char output_dir[PATH_MAX];
	if (output_dir_arg) {
		if (snprintf(output_dir, sizeof(output_dir), "%s", output_dir_arg) >= (int)sizeof(output_dir)) {
			fprintf(stderr, "Error: output directory path too long\n");
			return 1;
		}
	} else {
		if (!get_executable_dir(output_dir, sizeof(output_dir))) {
			fprintf(stderr, "Error: failed to resolve executable directory\n");
			return 1;
		}
	}

	char feeds_output[PATH_MAX];
	char packages_output[PATH_MAX];
	if (snprintf(feeds_output, sizeof(feeds_output), "%s/feeds.json", output_dir) >= (int)sizeof(feeds_output) ||
		snprintf(packages_output, sizeof(packages_output), "%s/packages.json", output_dir) >= (int)sizeof(packages_output)) {
		fprintf(stderr, "Error: output path too long\n");
		return 1;
	}

	if (update_mode == UPDATE_ALL || update_mode == UPDATE_FEEDS) {
		if (!write_feeds_json(feeds_output, &config)) {
			return 1;
		}
	}

	if (update_mode == UPDATE_ALL || update_mode == UPDATE_PACKAGES) {
		if (!write_packages_json(packages_output, &config)) {
			return 1;
		}
	}

	return 0;
}