require 'webrick'
require 'dbi'
require 'erb'
require 'rubygems'

#stringクラスのconcatメソッドを置き換えるパッチ
class String
  alias_method(:orig_concat, :concat)
  def concat(value)
    if RUBY_VERSION > "1.9"
      orig_concat value.force_encoding('UTF-8')
    else
      orig_concat value
    end
  end
end

config = {
  :Port => 8099,
  :DocumentRoot => "."
}


#拡張子erbのファイルをERBを呼び出して処理するERBHandlerと関連づける
WEBrick::HTTPServlet::FileHandler.add_handler("erb", WEBrick::HTTPServlet::ERBHandler)

#WEBrickのHTTP Serverクラスのサーバインスタンスを作成する
server = WEBrick::HTTPServer.new(config)

#erbのMIMEタイプを設定
server.config[:MimeTypes]["erb"] = "text/html"

#一覧表示からの処理
server.mount_proc("/list") do |req, res|
  p req.query
  if /(.*)\.(delete|edit)$/ =~ req.query['oparation']   #.が任意の一文字, *が0回以上の繰り返し, $が末尾の一致を示す
    target_id = $1  #$1には、正規表現.*にマッチした部分が入る
    oparation = $2  #$2には、正規表現(delete|edit)にマッチした部分が入る
    #選択した処理を実行する画面へ以降
    #ERBを、ERBHandlerを経由せずに直接呼び出す
      if oparation == "delete"
        templete = ERB.new(File.read('delete.erb'))
      elsif oparation == "edit"
        templete = ERB.new(File.read('edit.erb'))
      end
      res.body << templete.result( binding )  #これをすることによって、delete.erbやedit.erbでtarget_idの値が使えるようになる
  else  #データが選択されていないときの例外処理
    templete = ERB.new(File.read('noselected.erb'))
    res.body << templete.result( binding )
  end
end

#登録の処理
server.mount_proc("/entry") do |req, res|
  p req.query
  dbh = DBI.connect('DBI:SQLite3:book_info_sqlite3.db')
  rows = dbh.select_one("select * from bookinfos where id ='#{req.query['id']}';")
  if rows then  #もしrowが見つかれば、idがすでに登録されているのでデータベースを終了する
    dbh.disconnect
    templete = ERB.new(File.read('noentried.erb'))
    res.body << templete.result(binding)
    
  else
    #テーブルにデータを追加する
    dbh.do("insert into bookinfos values('#{req.query['id']}','#{req.query['title']}','#{req.query['author']}','#{req.query['page']}','#{req.query['publish_date']}');")
    dbh.disconnect
    templete = ERB.new(File.read('entried.erb'))
    res.body << templete.result(binding)

  end
end

#検索の処理
server.mount_proc("/retrieve") do |req, res|
  #本来ならここで不正な動作がないか調べるべき
  a = ['id','title','author','page','publish_date']
  a.delete_if {|name| req.query[name] == ""}
  if a.empty?
    where_data = ""
  else
    a.map! {|name| "#{name} = '#{req.query[name]}'"}
    where_data = "where " + a.join(' or ')
  end
  templete = ERB.new(File.read('retrieved.erb'))
  res.body << templete.result( binding )
end

#修正の処理
server.mount_proc("/edit") do |req, res|
  p req.query
  #本来ならここで不正な動作がないか調べるべき
  dbh = DBI.connect("DBI:SQLite3:book_info_sqlite3.db")
  dbh.do("update bookinfos set id='#{req.query['id']}',title='#{req.query['title']}',author='#{req.query['author']}',page='#{req.query['page']}',publish_date='#{req.query['publish_date']}' where id='#{req.query['id']}';")

  dbh.disconnect
  templete = ERB.new(File.read('edited.erb'))
  res.body << templete.result( binding )
end

#削除の処理
server.mount_proc("/delete") do |req, res|
  p req.query
  #本来ならここで不正な動作がないか調べるべき
  dbh = DBI.connect("DBI:SQLite3:book_info_sqlite3.db")
  dbh.do("delete from bookinfos where id = '#{req.query['id']}';")

  dbh.disconnect
  templete = ERB.new(File.read('deleted.erb'))
  res.body << templete.result( binding )
end

#ctrl -C が押されたときにサーバを停止する処理
trap(:INT) do
  server.shutdown
end

#サーバスタート
server.start
