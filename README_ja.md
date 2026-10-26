# GD25Q127C（16MB）搭載 Pico 2 互換ボード用 MicroPython

[English](README.md)

Raspberry Pi Pico 2 とピン配置が同じで、フラッシュに **GigaDevice GD25Q127C**（16MB、
印字 `25q127cs16`）を載せた RP2350 互換ボード向けの MicroPython ボード定義です。

このボードでは、公式の Pico 2 用 MicroPython を書き込んでも**起動しません**。USB の
シリアルポート（`/dev/ttyACM0`）が現れず、CircuitPython の `raspberry_pi_pico2` 用 UF2
だけが動く状態になります。このリポジトリのボード定義を使うと起動し、16MB の
フラッシュもすべて使えるようになります。

## 症状

- 公式の `RPI_PICO2` 用 UF2 をコピーすると `RP2350` ドライブは消える（リセットはかかる）が、
  シリアルポートが出てこない。
- PC 側の USB デバイス一覧にも出てこない。
- 同じボードで CircuitPython は動く。

## 原因

公式の Pico 2 のボード定義は、フラッシュを **75MHz**（150MHz / `PICO_FLASH_SPI_CLKDIV 2`）
で動かします。この値は起動時にフラッシュを設定する処理（boot2）と、起動後に MicroPython が
フラッシュのタイミングを設定し直す処理（`ports/rp2/rp2_flash.c` の `rp2_flash_set_timing()`）
の両方で使われます。このボードの GD25Q127C はその速度では安定して動かず、
**37.5MHz**（`PICO_FLASH_SPI_CLKDIV 4`）に下げると起動します。

確認の経過は[調査の記録](#調査の記録)を参照してください。

## 公式 `RPI_PICO2` との違い

| 設定 | RPI_PICO2 | このボード（`PICO2_GD25Q127C`） |
|---|---|---|
| フラッシュサイズ | 4MB | 16MB |
| ファイルシステム | 3MB | 14MB |
| フラッシュのクロック | 150MHz / 2 = 75MHz | 150MHz / 4 = **37.5MHz** |
| boot2 | `boot2_w25q080`（QE ビットを `0x01` で書き込む） | `boot2_gd25q127c`（QE ビットを `0x31` で書き込む） |
| 水晶の起動待ち | ×6（SDK 既定） | ×64 |
| 追加のピン名 | — | `GP23`、`GP24` |

| ファイル | 内容 |
|---|---|
| `pico2_16mb.h` | pico-sdk のボードヘッダ。フラッシュ 16MB、`PICO_FLASH_SPI_CLKDIV 4`、`PICO_XOSC_STARTUP_DELAY_MULTIPLIER 64` を定義し、残りは SDK の `boards/pico2.h` を継承する |
| `boot2_gd25q127c.S` | GD25Q127C 用の boot2。pico-sdk の `boot2_w25q080.S` を元に修正（下記） |
| `mpconfigboard.cmake` | 上記のヘッダと boot2 を使う設定。ファイルシステムは 14MB（16MB − ファームウェア用 2MB） |
| `mpconfigboard.h`・`board.json`・`pins.csv`・variant | MicroPython の `RPI_PICO2` を元に、ボード名を変更し `GP23`/`GP24` を追加 |

### boot2_gd25q127c.S の変更点（boot2_w25q080.S との差分）

- Quad モードを有効にするステータスレジスタの書き込みを、`0x01 00 02`（SR1 と SR2 を
  続けて書く）から `0x31 02`（SR2 だけを書く）に変更した。GD25Q127C のデータシートでは
  SR2 の書き込みは `0x31` なので、W25Q080 の手順ではこのチップの QE ビットは立たないはず。
- SR2 全体を `0x02` と比べるのをやめ、QE ビット（bit1）だけを調べるようにした。ほかの
  ビットが立っていても、起動のたびにステータスレジスタを書き換えることはない。
- Arm 版と RISC-V 版の両方を修正したが、**RISC-V 版はビルドもテストもしていない**。

## ビルド

ボード定義はこのリポジトリに置いたまま、MicroPython の rp2 ポートに `BOARD_DIR` で
渡してビルドします。MicroPython 側のファイルは変更しません。

必要なもの: MicroPython の git clone、`arm-none-eabi-gcc`、CMake、make、Python 3
（通常の MicroPython rp2 ビルドと同じ）。

```sh
git clone https://github.com/micropython/micropython.git
git clone <このリポジトリ> micropython-pico2-gd25q127c
cd micropython-pico2-gd25q127c
./build.sh ../micropython
# -> ../micropython/ports/rp2/build-PICO2_GD25Q127C/firmware.uf2
```

手動でビルドする場合:

```sh
cd micropython/ports/rp2
make -C ../../mpy-cross
make BOARD_DIR=/path/to/micropython-pico2-gd25q127c/boards/PICO2_GD25Q127C submodules
make BOARD_DIR=/path/to/micropython-pico2-gd25q127c/boards/PICO2_GD25Q127C
```

ファイルシステムの容量は `MICROPY_HW_FLASH_STORAGE_BYTES` で変更できます。

```sh
make BOARD_DIR=... MICROPY_HW_FLASH_STORAGE_BYTES=15728640   # 15MB
```

MicroPython v1.29.0-preview で確認しています。

## 書き込み

> [!WARNING]
> このファームウェアは、フラッシュが本当に **16MB** あるボード（チップの印字が `25q127`
> など）にだけ使ってください。ファイルシステムを 14MB 確保するため、フラッシュがもっと
> 小さいボードでは、ファイルシステムへの書き込みがチップの先頭に折り返してファームウェア
> 自体を上書きします（BOOTSEL モードで書き直せば復旧できます）。同じ「起動しない」症状の
> ほかのボードは、[ほかのボード](#ほかのボード実験的)を参照してください。

1. BOOTSEL ボタンを押しながら USB に接続する。`RP2350` ドライブが現れる。
2. `firmware.uf2` をそのドライブにコピーする。
3. ボードが再起動し、シリアルポート（Linux では `/dev/ttyACM0`）が現れる。

16MB の構成になっているかの確認（約 `14336` と表示されれば OK）:

```python
import os; s = os.statvfs('/'); print(s[0] * s[2] // 1024)
```

## 対象ボード

| 項目 | 内容 |
|---|---|
| MCU | RP2350（Pico 2 と同じピン配置） |
| フラッシュ | 16MB、GigaDevice GD25Q127C（印字 `25q127cs16`） |
| GP23 | RGB LED |
| GP24 | タクトスイッチ |
| GP25 | LED（`Pin("LED")`） |

この種のボードはさまざまな名前で売られています。同じ印字のフラッシュなのに動作が
違う場合は Issue で知らせてください。

## 調査の記録

以下のテスト用ファームウェアは、すべて水晶の起動待ちを ×64 にしてビルドしています。

| ビルド | boot2 | フラッシュのクロック | 結果 |
|---|---|---|---|
| test1 | w25q080 | 75MHz | ✗ USB に出ない |
| test2 | gd25q127c（`0x31` で QE を設定） | 75MHz | ✗ USB に出ない |
| test3 | generic_03h（シリアル読み出し） | 75MHz | ✗ USB に出ない |
| diag1 | gd25q127c | 37.5MHz | **✓ USB で認識され、`mpremote` で接続できた** |

失敗した3つはどれもフラッシュを 75MHz で動かしていました（boot2 も
`PICO_FLASH_SPI_CLKDIV` を使うため、`generic_03h` も同じ）。test2 と diag1 の違いは
クロックだけなので、クロックを下げることが必須だとわかります。

切り分けていないこと:

- GD25Q127C 用の boot2 も必須かどうか（標準の W25Q080 用 boot2 を 37.5MHz で動かす
  組み合わせは試していない）。データシートに合っているので採用している。
- 水晶の起動待ちを長くした効果。起動が数十 ms 遅くなる程度なので残している。

補足: pico-sdk の `boot2_at25sf128a.S`（こちらも `0x31` で QE を設定する）は RP2350 用の
ディレクトリにありますが、RP2040 の SSI レジスタを使っているため RP2350 では使えません。

## ほかのボード（実験的）

16MB のフラッシュを持たないほかの RP2350 ボードでも、似たようなタイミングの理由で
MicroPython が起動しないことがあります。75MHz では安定しないフラッシュチップや、SDK の
待ち時間より起動の遅い水晶発振子です（後者の場合、書き込み直後やソフトウェアからの
リセットでは起動するのに、電源の入れ直しやリセットボタンの後は起動しません）。安全に
試せるのは、そのボード用の MicroPython のボード定義で、フラッシュの容量はそのままに
設定を1つだけ変えたものです。

| ボード | ボード定義 | テスト用 UF2 | 結果 |
|---|---|---|---|
| Cytron MOTION 2350 Pro（REV 2.0） | [`experimental/CYTRON_MOTION_2350_PRO_SLOWFLASH`](experimental/CYTRON_MOTION_2350_PRO_SLOWFLASH) — MicroPython の `CYTRON_MOTION_2350_PRO` のフラッシュのクロックを 37.5MHz にしたもの（フラッシュ 4MB／ファイルシステム 1MB は公式のまま） | [cytron-test1](https://github.com/MobileFF/micropython-pico2-gd25q127c/releases/tag/cytron-test1) | ✗ 書き込み直後は起動するが、電源の入れ直しやリセットボタンの後は起動しない（このボードではクロックは原因ではない） |
| Cytron MOTION 2350 Pro（REV 2.0） | [`experimental/CYTRON_MOTION_2350_PRO_SLOWXOSC`](experimental/CYTRON_MOTION_2350_PRO_SLOWXOSC) — MicroPython の `CYTRON_MOTION_2350_PRO` の水晶の起動待ちを 64 倍にしたもの（CircuitPython がこのボードで使っている値）。フラッシュのクロックは 75MHz | [cytron-test2](https://github.com/MobileFF/micropython-pico2-gd25q127c/releases/tag/cytron-test2) | 報告待ち |

注: CircuitPython ではこのボードのフラッシュは 2MB の W25Q16JV となっていますが、
MicroPython の公式のボード定義は 4MB とみなしています。

ビルドの方法はメインのボードと同じです。

```sh
cd micropython/ports/rp2
make BOARD_DIR=/path/to/micropython-pico2-gd25q127c/experimental/CYTRON_MOTION_2350_PRO_SLOWFLASH
```

## 状況

- [x] 診断用ビルド（37.5MHz＋GD25Q127C 用 boot2）が実機で起動
- [x] このボード定義が `BOARD_DIR` 指定でビルドできる
- [x] 完成版ビルドの実機確認：起動し、ファイルシステムは 14MB、フラッシュの読み出しは
      4/8/12MB 先で折り返さない（16MB すべてある）
- [ ] より速いクロック（例: 150MHz / 3 = 50MHz）で動くか
- [ ] RISC-V 版（`./build.sh ../micropython RISCV`）

## ライセンス

MIT（[LICENSE](LICENSE) 参照）。`boot2_gd25q127c.S` は pico-sdk のファイルを改変したもので、
ファイル冒頭に記載のとおり BSD-3-Clause（Copyright (c) 2019-2022 Raspberry Pi (Trading) Ltd.）
のままです。そのほかのボード定義ファイルは MicroPython の `RPI_PICO2` ボード定義（MIT）を
元にしています。

このプロジェクトは Raspberry Pi Ltd. および GigaDevice とは関係ありません。
