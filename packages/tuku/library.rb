require 'object'
require 'models'
require 'http_client'
require 'callback'
require 'data'
require 'xml'

class Library < HiEngine::Object

  HOST_URL = 'http://221.150.100.120'

  def parse path, on_complete
    begin
      doc = XMLDocument.new FileData.new(path), 1
      items = doc.xpath "//*[@class='searchResult']/*[@class='list']/*[@class='ib item']"
      books = []
      items.each do |item|
        book = Book.new
        img = item.findChild('class', 'ib img').getChild(0)
        book.url = HOST_URL + img.getAttribute('href')
        book.thumb = img.getChild(0).getAttribute('src')

        info = item.findChild('class', 'ib info')
        children = info.getChildren
        book.name = children[0].getChild(0).getContent.strip
        book.subtitle = children[1].getChild(1).getContent.strip
        book.des = children[3].getChild(1).getContent.strip
        books << book
      end
      on_complete.invoke [true, books]
    rescue Exception => e
      p e
      on_complete.invoke [false]
    end
  end

  def parse_book ori, path, on_complete
    begin
      doc = XMLDocument.new FileData.new(path), 1
      book = Book.new
      item = doc.xpath("//*[@class='mainForm']/*[@class='comicInfo']").first
      cover = item.findChild('class', 'ib cover').getChild(0).getChild(0)
      book.thumb = cover.getAttribute('src')

      info = item.findChild('class', 'ib info')
      book.name = info.getChild(0).getContent.strip
      begin
        book.subtitle = info.getChild(1).getChild(0).getChild(0).getContent.strip
      rescue Exception => e
        book.subtitle = ori.subtitle
      end
      content = info.xpath('p[@class="content"]').first
      begin
        c = content.getContent.strip
        if !c || c == ''
          book.des = info.getChild(4).getContent.strip
        else
          book.des = c
        end
      rescue Exception => e
        book.des = ori.des
      end
      book.url = ori.url

      on_complete.invoke [true, book, parse_chapters(doc), false]
    rescue Exception => e
      on_complete.inv false
    end
  end

  def parse_chapters doc
    items = doc.xpath("//*[@id='chapterlistload']/div[@class='list']/a[@class='ib']")

    chapters = []
    items.each do |item|
      chapter = Chapter.new
      chapter.name = item.getContent.strip
      chapter.url = HOST_URL + item.getAttribute('href')
      chapters << chapter
    end
    chapters
  end

  def parse_search path, on_complete
    begin
      doc = XMLDocument.new FileData.new(path), 1
      items = doc.xpath "//*[@class='bookList_3']/*[@class='item ib']"
      books = []
      items.each do |item|
        book = Book.new
        img = item.xpath('*[@class="book"]//img[@class="cover"]').first
        book.thumb = img.getAttribute('src')
        title = item.xpath('*[@class="title"]/a').first
        book.name = title.getContent.strip
        book.url = HOST_URL + title.getAttribute('href')

        tip = item.xpath('*[@class="tip"]/a').first
        book.des = tip.getContent.strip

        books << book
      end
      on_complete.inv true, books
    rescue Exception => e
      p e
      on_complete.inv false
    end
  end

  # @description 加载主页接口。
  # @param page 分页，从0开始
  # @param on_complete 结束回调
  # @return client 把请求反回，让主程序页面退出的时候有能力结束请求。
  #   不过这个client并不是关键要素，所以有一串请求时也不必担心，返回最开始的一个就行。
  def load page, on_complete
    type = self.settings.find('类别') || 0
    append = nil
    case type
      when 0
        append = "/newest/#{page+1}"
      when 1
        append = "/list/comic_1_#{page+1}.htm"
      when 2
        append = "/list/comic_2_#{page+1}.htm"
      when 3
        append = "/list/comic_6_#{page+1}.htm"
      when 4
        append = "/lianzai/#{page+1}"
      when 5
        append = "/wanjie/#{page+1}"
      else
        on_complete.invoke [false]
        return
    end
    client = HTTPClient.new HOST_URL + append
    client.on_complete = Callback.new do |c|
      if c.getError.length == 0
        parse c.path, on_complete
      else
        on_complete.invoke [false]
      end
    end
    client.start
    client
  end

  # @description 读去书本详细信息的接口。
  # @param book Book对象
  # @param page 分页，从0开始
  # @param on_complete 结束回调
  # @return client 把请求反回，让主程序页面退出的时候有能力结束请求。
  def loadBook book, page, on_complete
    client = HTTPClient.new book.url
    client.on_complete = Callback.new do |c|
      if c.getError.length == 0
        parse_book book, c.path, on_complete
      else
        on_complete.invoke [false]
      end
    end
    client.start
    client
  end

  # @description 搜索接口
  # @param key 搜索关键字
  # @param page 分页，从0开始
  # @param on_complete 结束回调
  # @return client 把请求反回，让主程序页面退出的时候有能力结束请求。
  def search key, page, on_complete
    client = HTTPClient.new "#{HOST_URL}/Search/index/nickname/#{HTTP::URL::encode key}/p/#{page+1}.html"
    client.on_complete = Callback.new do |c|
      if c.getError.length == 0
        parse_search c.path, on_complete
      else
        on_complete.inv false
      end
    end
    client.start
    client
  end

end
