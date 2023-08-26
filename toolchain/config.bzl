"""This module provides the cc_toolchain_config rule."""

load("@bazel_tools//tools/build_defs/cc:action_names.bzl", "ACTION_NAMES")
load(
    "@bazel_tools//tools/cpp:cc_toolchain_config_lib.bzl",
    "action_config",
    "feature",
    "flag_group",
    "flag_set",
    "tool",
    "tool_path",
    "with_feature_set",
)

all_compile_actions = [
    ACTION_NAMES.c_compile,
    ACTION_NAMES.cpp_compile,
    ACTION_NAMES.linkstamp_compile,
    ACTION_NAMES.assemble,
    ACTION_NAMES.preprocess_assemble,
    ACTION_NAMES.cpp_header_parsing,
    ACTION_NAMES.cpp_module_compile,
    ACTION_NAMES.cpp_module_codegen,
    ACTION_NAMES.clif_match,
    ACTION_NAMES.lto_backend,
]

all_cpp_compile_actions = [
    ACTION_NAMES.cpp_compile,
    ACTION_NAMES.linkstamp_compile,
    ACTION_NAMES.cpp_header_parsing,
    ACTION_NAMES.cpp_module_compile,
    ACTION_NAMES.cpp_module_codegen,
    ACTION_NAMES.clif_match,
]

preprocessor_compile_actions = [
    ACTION_NAMES.c_compile,
    ACTION_NAMES.cpp_compile,
    ACTION_NAMES.linkstamp_compile,
    ACTION_NAMES.preprocess_assemble,
    ACTION_NAMES.cpp_header_parsing,
    ACTION_NAMES.cpp_module_compile,
    ACTION_NAMES.clif_match,
]

codegen_compile_actions = [
    ACTION_NAMES.c_compile,
    ACTION_NAMES.cpp_compile,
    ACTION_NAMES.linkstamp_compile,
    ACTION_NAMES.assemble,
    ACTION_NAMES.preprocess_assemble,
    ACTION_NAMES.cpp_module_codegen,
    ACTION_NAMES.lto_backend,
]

all_link_actions = [
    ACTION_NAMES.cpp_link_executable,
    ACTION_NAMES.cpp_link_dynamic_library,
    ACTION_NAMES.cpp_link_nodeps_dynamic_library,
]

lto_index_actions = [
    ACTION_NAMES.lto_index_for_executable,
    ACTION_NAMES.lto_index_for_dynamic_library,
    ACTION_NAMES.lto_index_for_nodeps_dynamic_library,
]

def wrapper_path(ctx, tool):
    wrapped_path = "{}/riscv-none-elf-{}{}".format(ctx.attr.wrapper_path, tool, ctx.attr.wrapper_ext)
    return wrapped_path

def _impl(ctx):
    cxx_builtin_include_directories = ctx.attr.cxx_builtin_include_directories

    extra_cflags = ctx.attr.extra_cflags
    extra_cxxflags = ctx.attr.extra_cxxflags

    extra_ldflags = ctx.attr.extra_ldflags + [
        "-Lexternal/{}/riscv-none-elf/lib".format(ctx.attr.gcc_repo),
        "-Lexternal/{}/lib/gcc/riscv-none-elf/{}".format(ctx.attr.gcc_repo, ctx.attr.gcc_version),
    ]

    includes = ctx.attr.includes + [
        "external/{}/riscv-none-elf/include".format(ctx.attr.gcc_repo),
        "external/{}/lib/gcc/riscv-none-elf/{}/include".format(ctx.attr.gcc_repo, ctx.attr.gcc_version),
        "external/{}/lib/gcc/riscv-none-elf/{}/include-fixed".format(ctx.attr.gcc_repo, ctx.attr.gcc_version),
        "external/{}/riscv-none-elf/include/c++/{}/".format(ctx.attr.gcc_repo, ctx.attr.gcc_version),
        "external/{}/riscv-none-elf/include/c++/{}/riscv-none-elf/".format(ctx.attr.gcc_repo, ctx.attr.gcc_version),
    ]

    tool_paths = {
        "gcc": wrapper_path(ctx, "gcc"),
        "ld": wrapper_path(ctx, "ld"),
        "as": wrapper_path(ctx, "as"),
        "ar": wrapper_path(ctx, "ar"),
        "cpp": wrapper_path(ctx, "cpp"),
        "gcov": wrapper_path(ctx, "gcov"),
        "nm": wrapper_path(ctx, "nm"),
        "objdump": wrapper_path(ctx, "objdump"),
        "objcopy": wrapper_path(ctx, "objcopy"),
        "strip": wrapper_path(ctx, "strip"),
    }

    action_configs = []

    action_configs.append(action_config(
        action_name = "objcopy_embed_data",
        enabled = True,
        tools = [tool(path = tool_paths.get("objcopy"))],
    ))

    default_link_flags_feature = feature(
        name = "default_link_flags",
        enabled = True,
        flag_sets = [
            flag_set(
                actions = all_link_actions,
                flag_groups = [
                    flag_group(
                        flags = [
                            "-pass-exit-codes",
                        ],
                    ),
                ],
            ),
        ],
    )

    unfiltered_compile_flags_feature = feature(
        name = "unfiltered_compile_flags",
        enabled = True,
        flag_sets = [
            flag_set(
                actions = all_compile_actions,
                flag_groups = [
                    flag_group(
                        flags = [
                            "-no-canonical-prefixes",
                            "-fno-canonical-system-headers",
                            "-Wno-builtin-macro-redefined",
                        ],
                    ),
                ],
            ),
        ],
    )

    redacted_dates_feature = feature(
        name = "redacted_dates",
        enabled = True,
        flag_sets = [
            flag_set(
                actions = all_compile_actions,
                flag_groups = [
                    flag_group(
                        flags = [
                            "-D__DATE__=\"redacted\"",
                            "-D__TIMESTAMP__=\"redacted\"",
                            "-D__TIME__=\"redacted\"",
                        ],
                    ),
                ],
            ),
        ],
    )

    supports_pic_feature = feature(
        name = "supports_pic",
        enabled = True,
    )

    default_compile_flags_feature = feature(
        name = "default_compile_flags",
        enabled = True,
        flag_sets = [
            flag_set(
                actions = all_cpp_compile_actions,
                flag_groups = [
                    flag_group(
                        flags = [
                            "-fstack-protector",
                            "-Wall",
                            "-Wunused-but-set-parameter",
                            "-Wno-free-nonheap-object",
                            "-fno-omit-frame-pointer",
                        ],
                    ),
                ],
            ),
            flag_set(
                actions = all_cpp_compile_actions,
                flag_groups = [
                    flag_group(
                        flags = [
                            "-U_FORTIFY_SOURCE",
                            "-D_FORTIFY_SOURCE=1",
                        ],
                    ),
                ],
                with_features = [with_feature_set(features = ["opt"])],
            ),
            flag_set(
                actions = all_cpp_compile_actions,
                flag_groups = [flag_group(flags = ["-g"])],
                with_features = [with_feature_set(features = ["dbg"])],
            ),
            flag_set(
                actions = all_cpp_compile_actions,
                flag_groups = [
                    flag_group(
                        flags = [
                            "-ffunction-sections",
                            "-fdata-sections",
                        ],
                    ),
                ],
                with_features = [with_feature_set(features = ["opt"])],
            ),
        ],
    )

    include_paths_feature = feature(
        name = "include_paths",
        enabled = True,
        flag_sets = [
            flag_set(
                actions = [
                    ACTION_NAMES.preprocess_assemble,
                    ACTION_NAMES.linkstamp_compile,
                    ACTION_NAMES.c_compile,
                    ACTION_NAMES.cpp_compile,
                    ACTION_NAMES.cpp_header_parsing,
                    ACTION_NAMES.cpp_module_compile,
                    ACTION_NAMES.clif_match,
                    ACTION_NAMES.objc_compile,
                    ACTION_NAMES.objcpp_compile,
                ],
                flag_groups = [
                    flag_group(
                        flags = ["-iquote", "%{quote_include_paths}"],
                        iterate_over = "quote_include_paths",
                    ),
                    flag_group(
                        flags = ["-I%{include_paths}"],
                        iterate_over = "include_paths",
                    ),
                    flag_group(
                        flags = ["-isystem", "%{system_include_paths}"],
                        iterate_over = "system_include_paths",
                    ),
                ],
            ),
        ],
    )

    library_search_directories_feature = feature(
        name = "library_search_directories",
        flag_sets = [
            flag_set(
                actions = all_link_actions + lto_index_actions,
                flag_groups = [
                    flag_group(
                        flags = ["-L%{library_search_directories}"],
                        iterate_over = "library_search_directories",
                        expand_if_available = "library_search_directories",
                    ),
                ],
            ),
        ],
    )

    opt_feature = feature(name = "opt")

    supports_dynamic_linker_feature = feature(
        name = "supports_dynamic_linker",
        enabled = False,
    )

    objcopy_embed_flags_feature = feature(
        name = "objcopy_embed_flags",
        enabled = True,
        flag_sets = [
            flag_set(
                actions = ["objcopy_embed_data"],
                flag_groups = [flag_group(flags = ["-I", "binary"])],
            ),
        ],
    )

    dbg_feature = feature(name = "dbg")

    extra_cflags_feature = feature(
        name = "extra_cflags",
        enabled = True,
        flag_sets = [
            flag_set(
                actions = all_compile_actions,
                flag_groups = [flag_group(flags = extra_cflags)],
            ),
        ] if len(extra_cflags) > 0 else [],
    )

    extra_cxxflags_feature = feature(
        name = "extra_cxxflags",
        enabled = True,
        flag_sets = [
            flag_set(
                actions = [ACTION_NAMES.cpp_compile],
                flag_groups = [flag_group(flags = extra_cxxflags)],
            ),
        ] if len(extra_cxxflags) > 0 else [],
    )

    includes_feature = feature(
        name = "includes",
        enabled = True,
        flag_sets = [
            flag_set(
                actions = all_compile_actions,
                flag_groups = [flag_group(flags = [
                    "-isystem{}".format(include)
                    for include in includes
                ])],
            ),
        ] if len(includes) > 0 else [],
    )

    extra_ldflags_feature = feature(
        name = "extra_ldflags",
        enabled = True,
        flag_sets = [
            flag_set(
                actions = all_link_actions,
                flag_groups = [flag_group(flags = extra_ldflags)],
            ),
        ] if len(extra_ldflags) > 0 else [],
    )

    sysroot_feature = feature(
        name = "sysroot",
        enabled = True,
        flag_sets = [
            flag_set(
                actions = [
                    ACTION_NAMES.preprocess_assemble,
                    ACTION_NAMES.linkstamp_compile,
                    ACTION_NAMES.c_compile,
                    ACTION_NAMES.cpp_compile,
                    ACTION_NAMES.cpp_header_parsing,
                    ACTION_NAMES.cpp_module_compile,
                    ACTION_NAMES.cpp_module_codegen,
                    ACTION_NAMES.lto_backend,
                    ACTION_NAMES.clif_match,
                ] + all_link_actions + lto_index_actions,
                flag_groups = [
                    flag_group(
                        flags = ["--sysroot", "%{sysroot}"],
                        expand_if_available = "sysroot",
                    ),
                ],
            ),
        ],
    )

    features = [
        default_compile_flags_feature,
        include_paths_feature,
        library_search_directories_feature,
        default_link_flags_feature,
        supports_dynamic_linker_feature,
        supports_pic_feature,
        objcopy_embed_flags_feature,
        opt_feature,
        dbg_feature,
        sysroot_feature,
        unfiltered_compile_flags_feature,
        redacted_dates_feature,
        extra_cflags_feature,
        extra_cxxflags_feature,
        extra_ldflags_feature,
        includes_feature,
    ]

    return [
        cc_common.create_cc_toolchain_config_info(
            ctx = ctx,
            toolchain_identifier = ctx.attr.toolchain_identifier,
            host_system_name = ctx.attr.host_system_name,
            target_system_name = "riscv-none-elf",
            target_cpu = "riscv-none-elf",
            target_libc = "gcc",
            compiler = ctx.attr.gcc_repo,
            abi_version = "eabi",
            abi_libc_version = ctx.attr.gcc_version,
            tool_paths = [
                tool_path(name = name, path = path)
                for name, path in tool_paths.items()
            ],
            features = features,
            action_configs = action_configs,
            cxx_builtin_include_directories = cxx_builtin_include_directories,
        ),
    ]

cc_riscv_none_elf_config = rule(
    implementation = _impl,
    attrs = {
        "toolchain_identifier": attr.string(default = ""),
        "host_system_name": attr.string(default = ""),
        "wrapper_path": attr.string(default = ""),
        "wrapper_ext": attr.string(default = ""),
        "gcc_repo": attr.string(default = ""),
        "gcc_version": attr.string(default = ""),
        "cxx_builtin_include_directories": attr.string_list(default = []),
        "extra_cflags": attr.string_list(default = []),
        "extra_cxxflags": attr.string_list(default = []),
        "extra_ldflags": attr.string_list(default = []),
        "includes": attr.string_list(default = []),
        "tool_paths": attr.string_dict(default = {}),
    },
    provides = [CcToolchainConfigInfo],
)
