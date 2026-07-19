#!/usr/bin/env python3
"""
从当前 Xcode 镜像上"实际可用"的模拟器列表里，挑选一个 iPhone 型号用于跑单元测试。

不写死具体型号名（比如 "iPhone 16"），是因为苹果每次更新模拟器镜像，
默认提供的机型阵容都可能变化（这正是上一次构建失败的原因：镜像升级后
"iPhone 16" 这个型号名已经不在默认列表里了）。这个脚本改成运行时动态查询，
以后镜像再怎么变，都能自动适配。

用法：
    python3 .github/scripts/pick_simulator.py
读取标准输入（xcrun simctl list devices available -j 的 JSON 输出），
输出一个可用的 iPhone 型号名到标准输出（只有型号名这一行，方便 shell 直接用 $() 取值）。
"""
import json
import re
import sys


def main():
    data = json.load(sys.stdin)

    candidates = []
    for runtime, devices in data.get("devices", {}).items():
        if "iOS" not in runtime:
            continue
        for device in devices:
            name = device.get("name", "")
            if name.startswith("iPhone") and device.get("isAvailable", True):
                candidates.append(name)

    if not candidates:
        sys.exit("没有找到任何可用的 iPhone 模拟器，请检查 Xcode 镜像里的模拟器安装情况")

    # 优先选择"普通数字型号"（比如 iPhone 17），避开 Pro / Pro Max / Air / e 这些变体，
    # 这样测试用的设备尺寸更具代表性；如果找不到普通型号，就退回随便选第一个可用的 iPhone。
    plain_models = [name for name in candidates if re.fullmatch(r"iPhone \d+", name)]
    chosen = plain_models[0] if plain_models else candidates[0]
    print(chosen)


if __name__ == "__main__":
    main()
