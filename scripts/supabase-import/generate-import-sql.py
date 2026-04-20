"""
讀取 0413親證班名單套用定聚家族+大家長.xlsx
產出一份 SQL 檔，包含：
  1. ALTER members 讓 squad_id 可空（給大隊長用）
  2. INSERT 18 大隊
  3. INSERT ~55 小隊
  4. INSERT 414 成員（大隊長 + 小隊長 + 一般隊員）
"""
import pandas as pd
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding='utf-8')

XLSX = Path(r"C:/Coding Project/Corporate Website/cchengroad-Scoring System/給Claude讀取的資料/0413親證班名單套用定聚家族+大家長.xlsx")
OUT = Path(r"C:/Coding Project/Corporate Website/cchengroad-Scoring System/scripts/supabase-import/02-import-members.sql")

# 18 大隊定義（手動整理，保留地區與暱稱資訊）
# (team_code, sheet_name, region, nickname, has_team_name)
TEAMS = [
    ("T01", "（嘉義）平安", "嘉義", "平安", "嘉家久"),   # 大隊名已填
    ("T02", "（嘉義）士騰", "嘉義", "士騰", None),
    ("T03", "（北台南）周展", "北台南", "周展", "大展鴻圖"),
    ("T04", "（台南）Mike", "台南", "Mike", None),
    ("T05", "（台南）谷哥", "台南", "谷哥", None),
    ("T06", "（台南）茵茵", "台南", "茵茵", None),
    ("T07", "（台南） Happy", "台南", "Happy", None),
    ("T08", "（台南）阿長", "台南", "阿長", "隨喜"),      # 大隊名已填
    ("T09", "（北高雄）佳音", "北高雄", "佳音", None),
    ("T10", "（大行）巧巧", "大行", "巧巧", None),
    ("T11", "（大行）又甫", "大行", "又甫", None),
    ("T12", "（高雄）語婕", "高雄", "語婕", None),
    ("T13", "（高雄）愫娟", "高雄", "愫娟", None),
    ("T14", "（高雄）冠美", "高雄", "冠美", None),
    ("T15", "（高雄）郭政呈", "高雄", "郭政呈", None),
    ("T16", "（高雄）沛宭", "高雄", "沛宭", None),
    ("T17", "（屏東）鎂媛", "屏東", "鎂媛", None),
    ("T18", "（屏東）伶儒", "屏東", "伶儒", None),
]

def sq(s):
    """SQL 字串跳脫"""
    if s is None:
        return "NULL"
    return "'" + str(s).replace("'", "''").strip() + "'"

def resolve_team_name(region, nickname, has_name):
    """未填大隊名 → 地區 + 暱稱"""
    if has_name:
        return has_name
    return f"{region}{nickname}"

def main():
    sql_lines = []
    sql_lines.append("-- =====================================================")
    sql_lines.append("-- 名單匯入 SQL：18 大隊 / ~55 小隊 / ~414 成員")
    sql_lines.append("-- 產出時間：2026-04-20")
    sql_lines.append("-- 來源：0413親證班名單套用定聚家族+大家長.xlsx")
    sql_lines.append("-- =====================================================")
    sql_lines.append("")

    # 0. 讓 squad_id 可空（大隊長不屬於任何小隊）
    sql_lines.append("-- 0. 調整 schema：允許 members.squad_id 為 NULL（給大隊長用）")
    sql_lines.append("ALTER TABLE members ALTER COLUMN squad_id DROP NOT NULL;")
    sql_lines.append("")

    # 1. INSERT teams
    sql_lines.append("-- 1. 匯入 18 大隊")

    team_rows = []
    team_summary = []
    for (code, sheet, region, nickname, has_name) in TEAMS:
        df = pd.read_excel(XLSX, sheet_name=sheet, header=None)
        leader = str(df.iloc[0, 1]).strip() if pd.notna(df.iloc[0, 1]) else None
        team_name = resolve_team_name(region, nickname, has_name)
        team_rows.append(f"({sq(code)}, {sq(team_name)}, {sq(leader)}, {sq(region)})")
        team_summary.append((code, team_name, leader, region))

    sql_lines.append("INSERT INTO teams (team_code, team_name, leader_name, region) VALUES")
    sql_lines.append(",\n".join("  " + r for r in team_rows) + ";")
    sql_lines.append("")

    # 2. INSERT squads — 每個小隊 squad_code = {team_code}{squad_num}
    sql_lines.append("-- 2. 匯入所有小隊（squad_code = team_code + squad_num，如 T011 = T01 的第 1 小隊）")
    squad_rows = []
    all_squads = []  # (squad_code, team_code, leader_name)
    squad_member_map = {}  # squad_code -> [member_name1, member_name2, ...]

    team_leaders = {}  # team_code -> team_leader_name

    for (code, sheet, region, nickname, has_name) in TEAMS:
        df = pd.read_excel(XLSX, sheet_name=sheet, header=None)
        team_leader = str(df.iloc[0, 1]).strip() if pd.notna(df.iloc[0, 1]) else None
        team_leaders[code] = team_leader

        # 小隊長在 row 2 (index 2)，從 column 1 開始
        # 人數在 row 3 (index 3)
        # 隊員從 row 4 開始
        squad_num = 0
        for col in range(1, df.shape[1]):
            if pd.isna(df.iloc[2, col]):
                continue
            squad_num += 1
            squad_leader = str(df.iloc[2, col]).strip()
            squad_code = f"{code}{squad_num}"
            all_squads.append((squad_code, code, squad_leader))
            squad_rows.append(
                f"((SELECT id FROM teams WHERE team_code = {sq(code)}), {sq(squad_code)}, {sq(squad_leader)})"
            )

            # 收集該小隊的隊員名單（精準用 人數 欄位，人數 = 小隊長 + 隊員）
            raw_count = df.iloc[3, col]
            if pd.isna(raw_count):
                expected_members = 0
            else:
                try:
                    expected_members = int(raw_count) - 1
                except (ValueError, TypeError):
                    expected_members = 0

            members = []
            for row in range(4, 4 + expected_members):
                if row >= df.shape[0]:
                    break
                cell = df.iloc[row, col]
                if pd.notna(cell):
                    cell_str = str(cell).strip()
                    if cell_str:
                        members.append(cell_str)
            squad_member_map[squad_code] = members

    sql_lines.append("INSERT INTO squads (team_id, squad_code, leader_name) VALUES")
    sql_lines.append(",\n".join("  " + r for r in squad_rows) + ";")
    sql_lines.append("")

    # 3. INSERT members
    sql_lines.append("-- 3. 匯入所有成員（大隊長 + 小隊長 + 隊員，PIN 預設 0000）")
    member_rows = []
    total_members = 0

    # 3a. 大隊長（squad_id = NULL, role = team_leader）
    for code in [t[0] for t in TEAMS]:
        leader = team_leaders[code]
        team_name = next(t[1] for t in team_summary if t[0] == code)
        member_code = f"{code}_{leader}_{team_name}"
        member_rows.append(
            f"(\n    {sq(member_code)}, {sq(leader)},\n"
            f"    (SELECT id FROM teams WHERE team_code = {sq(code)}),\n"
            f"    NULL, 'team_leader', '0000'\n  )"
        )
        total_members += 1

    # 3b. 小隊長（role = squad_leader）
    for (squad_code, team_code, squad_leader) in all_squads:
        team_name = next(t[1] for t in team_summary if t[0] == team_code)
        member_code = f"{squad_code}_{squad_leader}_{team_name}"
        member_rows.append(
            f"(\n    {sq(member_code)}, {sq(squad_leader)},\n"
            f"    (SELECT id FROM teams WHERE team_code = {sq(team_code)}),\n"
            f"    (SELECT id FROM squads WHERE squad_code = {sq(squad_code)}),\n"
            f"    'squad_leader', '0000'\n  )"
        )
        total_members += 1

    # 3c. 一般隊員（role = member）
    for (squad_code, team_code, _) in all_squads:
        team_name = next(t[1] for t in team_summary if t[0] == team_code)
        for name in squad_member_map[squad_code]:
            member_code = f"{squad_code}_{name}_{team_name}"
            member_rows.append(
                f"(\n    {sq(member_code)}, {sq(name)},\n"
                f"    (SELECT id FROM teams WHERE team_code = {sq(team_code)}),\n"
                f"    (SELECT id FROM squads WHERE squad_code = {sq(squad_code)}),\n"
                f"    'member', '0000'\n  )"
            )
            total_members += 1

    sql_lines.append("INSERT INTO members (member_code, name, team_id, squad_id, role, pin_code) VALUES")
    sql_lines.append(",\n".join(member_rows) + ";")
    sql_lines.append("")

    # 4. 摘要註解
    sql_lines.append(f"-- 預期結果：teams=18, squads={len(all_squads)}, members={total_members}")

    # 寫出檔案
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text("\n".join(sql_lines), encoding='utf-8')

    print(f"✅ SQL 產出：{OUT}")
    print(f"   - 大隊：18")
    print(f"   - 小隊：{len(all_squads)}")
    print(f"   - 成員：{total_members}")
    print(f"     · 大隊長：18")
    print(f"     · 小隊長：{len(all_squads)}")
    print(f"     · 一般隊員：{total_members - 18 - len(all_squads)}")
    print()
    print("大隊摘要：")
    for (code, team_name, leader, region) in team_summary:
        print(f"  {code}  {team_name:<12}  大隊長: {leader}  ({region})")

if __name__ == "__main__":
    main()
