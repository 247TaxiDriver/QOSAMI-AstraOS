# Third-party licenses

QOSAMI OS and QOSAMI Core project code are licensed under GPL-3.0-or-later. Third-party
components keep their original licenses; this file does not relicense them.

## Rust crates in `Cargo.lock`

The versions and SPDX license expressions below were checked against the
crate metadata for the versions locked in this repository:

| Crate | Locked version | License |
|---|---:|---|
| `bit_field` | 0.10.3 | Apache-2.0 OR MIT |
| `bitflags` | 2.11.0 | MIT OR Apache-2.0 |
| `const_fn` | 0.4.12 | Apache-2.0 OR MIT |
| `limine` | 0.5.0 | MIT OR Apache-2.0 |
| `lock_api` | 0.4.14 | MIT OR Apache-2.0 |
| `rustversion` | 1.0.22 | MIT OR Apache-2.0 |
| `scopeguard` | 1.2.0 | MIT OR Apache-2.0 |
| `spin` | 0.9.8 | MIT |
| `volatile` | 0.4.6 | MIT OR Apache-2.0 |
| `x86_64` | 0.15.4 | MIT OR Apache-2.0 |

## Limine bootloader binary

The vendored Limine 10.x binary archive has a BSD-2-Clause license. Its notice
is preserved at [`tools/Limine-10.x-binary/LICENSE`](../tools/Limine-10.x-binary/LICENSE).

When redistributing binaries or source bundles, include all applicable
third-party notices and license texts with the distribution.
