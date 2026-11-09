import os
import pymysql

DB_HOST = os.environ["DB_HOST"]
DB_USER = os.environ["DB_USER"]
DB_PASS = os.environ["DB_PASS"]
DB_NAME = os.environ["DB_NAME"]

# ✨ Menggunakan DROP TABLE untuk membersihkan data lama ("Pencil" & "Notebook")
INIT_SQL = """
DROP TABLE IF EXISTS products;

CREATE TABLE products (
  sid VARCHAR(255) PRIMARY KEY,
  sname VARCHAR(255),
  scategory VARCHAR(255),
  sphoto VARCHAR(255),
  sprice INT
);

INSERT INTO products (sid, sname, scategory, sphoto, sprice) VALUES
('c006','クリスマスプディング','ホール','cake01.jpg',2000),
('c0002','ブッシュド・ノエル','シートケーキ','cake02.jpg',250),
('c0003','イチゴとシブースドケーキ','ショートケーキ','cake03.jpg',400);
"""

def handler(event, context):
    try:
        conn = pymysql.connect(
            host=DB_HOST,
            user=DB_USER,
            password=DB_PASS,
            database=DB_NAME,
            charset="utf8mb4",
            cursorclass=pymysql.cursors.DictCursor,
            connect_timeout=5,
            autocommit=True,
            client_flag=pymysql.constants.CLIENT.MULTI_STATEMENTS,
        )
    except Exception as e:
        return _response(500, f"<p>データベースに接続できません: {e}</p>")

    try:
        with conn.cursor() as cursor:
            # Jalankan pembersihan dan pengisian data kue
            cursor.execute(INIT_SQL)
            
            # Ambil data kue yang baru saja dimasukkan
            cursor.execute("SELECT sid, sname, scategory, sphoto, sprice FROM products")
            rows = cursor.fetchall()
    except Exception as e:
        return _response(500, f"<p>クエリの実行に失敗しました: {e}</p>")
    finally:
        conn.close()

    # HTML テーブルを生成
    rows_html = "\n".join(
        f"<tr><td>{r['sname']}</td><td>{r['scategory']}</td><td>{r['sprice']}</td></tr>"
        for r in rows
    )

    html = f"""<!DOCTYPE html>
<html>
<head><title>AWS DB test</title></head>
<body>
<header><h1>商品一覧</h1></header>
<table border="1">
<tr><td>商品名</td><td>カテゴリ</td><td>価格</td></tr>
{rows_html}
</table>
</body>
</html>"""

    return _response(200, html)

def _response(status_code: int, body: str) -> dict:
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "text/html; charset=utf-8"},
        "body": body,
    }