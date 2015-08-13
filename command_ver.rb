require 'dbi'
require 'date'

class BookInfo
  #初期化関数
  def initialize(title, author, page, publish_date)
    @title = title
    @author = author
    @page = page
    @publish_date = publish_date
  end

  attr_accessor :title, :author, :page, :publish_date

  def to_s
    "#{@title}, #{@author}, #{@page}, #{@publish_date}"
  end

  def to_csv(key)
    "#{key},#{@title},#{@author},#{@page},#{@publish_date}\n"
  end

  def toFormattedString (sep = "\n")
    "書籍名:#{@title}#{sep}著者名:#{@author}#{sep}ページ数:#{@page}ページ#{sep}発行日:#{@publish_date}#{sep}"
  end
end


class BookInfoManager
  def initialize(sqlite_name)
    #初期化時にファイルネーム指定
    @db_name = sqlite_name
    #蔵書データのハッシュ
    @dbh = DBI.connect("DBI:SQLite3:#{@db_name}")
    #テーブル上の項目を日本語に変換するハッシュ
    @item_name = {'id' => 'キー', 'title' => 'タイトル', 'author' => '著者', 'page' => 'ページ数', 'publish_date' => '発刊日' }

  end

  def setUp
    open_file = open(@csv_fname, "r:UTF-8")
    open_file.each do |line|
      key, title, author,page, pdate = line.chomp.split(",")
      @book_infos[key] = BookInfo.new(title,author,page.to_i,Date.strptime(pdate))
    end
    open_file.close
  end

  def addBookInfo
    puts "\n1. 蔵書データの登録\n"
    book_info = BookInfo.new("","",0,Date.new)
    puts
    print "キー: "
    key = gets.chomp
    print "書籍名: "
    book_info.title = gets.chomp
    print "著者名: "
    book_info.author = gets.chomp
    print "ページ数: "
    book_info.page = gets.chomp.to_i
    print "発行年: "
    year = gets.chomp.to_i
    print "発行月: "
    month = gets.chomp.to_i
    print "発行日: "
    day = gets.chomp.to_i
    book_info.publish_date = Date.new(year,month,day)
    @dbh.do("insert into bookinfos values (
            \'#{key}\',
            \'#{book_info.title}\',
            \'#{book_info.author}\',
            \'#{book_info.page}\',
            \'#{book_info.publish_date}\'
       );")
    puts "\n登録しました"
  end
  
  def initBookInfo
    puts "\n0. データベースの初期化\n"
    print "初期化しますか？(Y/y)で初期化を実行: "
    yesno = gets.chomp.upcase
    if /^Y$/ =~ yesno
      @dbh.do("drop table if exists bookinfos")
      @dbh.do("create table bookinfos(
                id            varchar(50)       not null,
                title         varchar(100)      not null,
                author        varchar(100)      not null,
                page          int               not null,
                publish_date  datetime          not null,
                primary       key(id)    
                );")
      puts "\nデータベースを初期化しました"
    end
  end


  def delBookInfo
    puts "\n3. 蔵書データの削除\n"
    print "消す蔵書データのキーを入力してください: "
    delete_key = gets.chomp
    sth = @dbh.execute("delete from bookinfos where id = '#{delete_key}'")
    puts "削除しました"
    sth.finish
  end


  def listAllBookInfos
    puts "\n2. 蔵書データの表示\n"
    puts "蔵書データを表示します"
    counts = 0
    puts "-------------------------------------"
    sth = @dbh.execute("select * from bookinfos")
      sth.each do |row|
        row.each_with_name do |val,name|
          puts "#{@item_name[name]}: #{val.to_s}"
        end
      puts "-------------------------------------"
      counts += 1
    end
    sth.finish
    puts "#{counts}件表示しました"
  end


  def updateBookInfo
    puts "\n4. 蔵書データの更新\n"
    print "更新するデータのキーを入力してください: "
    update_key = gets.chomp
    sth = @dbh.execute("select * from bookinfos")
    puts "\nキーに対応するデータを表示します"
    puts "-------------------------------------"
    sth.each do |row|
      row.each_with_name do |val,name|
        puts "#{@item_name[name]}: #{val.to_s}"
      end
      puts "-------------------------------------"
    end
    puts "\n更新するデータを選んでください(id,title,author,page)"
    update_name = gets.chomp.to_s
    puts "#{@item_name[update_name]}の値を何に更新しますか？"
    new_value = gets.chomp.to_s if update_name != "page"
    new_value = gets.chomp.to_i if update_name == "page"
    @dbh.do("update bookinfos set '#{update_name}' = '#{new_value}' where id = '#{update_key}'")
    puts "更新しました"
  end

  def run
    while true
      print "
0.データベースの初期化
1.蔵書データの登録
2.蔵書データの表示
3.蔵書データの削除
4.蔵書データの編集
9.終了               
番号を選んでください(1,2,3,4,9,0): "
      num = gets.chomp.to_i
      case num
      when 0
        #データベースの初期化
        initBookInfo
      when 1
        #蔵書データの登録
        addBookInfo
      when 2
        #蔵書データの表示
        listAllBookInfos
      when 3
        #蔵書データの削除
        delBookInfo
      when 4
        #蔵書データの編集
        updateBookInfo
      when 9
        @dbh.disconnect
        #終了
        puts "\n終了しました"
        break;
       else
        #エラーメッセージを作ってもう一度
        puts "その操作は登録されていません"
      end
    end
  end
end


book_info_manager = BookInfoManager.new("book_info_sqlite3.db")
book_info_manager.run

