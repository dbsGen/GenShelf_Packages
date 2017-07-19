require 'object'
require 'models'
require 'http_client'
require 'callback'
require 'data'
require 'xml'

class Reader < HiEngine::Object
  HOST_URL = 'http://221.150.100.120'
  @stop = false

  def process chapter
    @stop = false
    page = Page.new
    page.url = chapter.url
    load_page page, 0
  end

  def load_page page, idx
    page.status = 0
    @client = HTTPClient.new page.url
    @client.read_cache = true
    @client.retry_count = 3
    @client.on_complete = Callback.new do |c|
      @client = nil
      return if @stop
      if c.getError.length == 0
        page.status = 1
        parse_page page, c.path do |url|
          loadedPage idx, true, page
          if url == nil or url['javascript'] != nil
            self.on_page_count.invoke [true, idx+1]
          else
            np = Page.new
            np.url = HOST_URL+url
            load_page np, idx+1
          end
        end
      else
        p "download failed #{c.getError}"
        page.status = -1
        loadedPage idx, false, page
        self.on_page_count.inv false
      end
    end
    @client.start
  end

  def parse_page page, path
    doc = XMLDocument.new FileData.new(path), 1
    node = doc.xpath("//*[@id='cp_img']/a").first
    page.picture = node.getChild(0).getAttribute 'src'
    found = false
    arr = doc.xpath("//a[@class='s_next']")

    arr.each do |a_node|
      if a_node.getContent == '下一页'
        yield a_node.getAttribute 'href'
        found = true
        break
      end
    end

    yield nil unless found
  end

  def stop
    @stop = true
    if @client
      @client.cancel
    end
  end

  def reloadPage page, idx, on_complete
    @stop = false
    page.status = 0
    @client = HTTPClient.new page.url
    @client.read_cache = false
    @client.retry_count = 3

    @client.on_complete = Callback.new do |c|
      @client = nil
      return if @stop
      if c.getError.length == 0
        page.status = 1
        parse_page page, c.path do |url|
          on_complete.inv true, page
        end
      else
        page.status = -1
        on_complete.inv false, page
      end
    end
    @client.start
    @client
  end
end
