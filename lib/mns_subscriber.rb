#!/usr/bin/env ruby

# file: mns_subscriber.rb


require 'mtlite'
require 'sps-sub'
require 'daily_notices'
require 'recordx_sqlite'
require 'easyimg_utils'


module MNSSubscriber

  class NoticeMgr
    include RXFHelperModule
    using ColouredText

    def initialize(sps=nil, dir: '.', options: {}, timeline: nil,
                  hashtag_url: nil, log: nil, debug: false)

      @sps, @log, @debug = sps, log, debug

      # note: a valid url_base must be provided
      @options = {
        url_base: 'http://yourwebsitehere.co.uk/',
        dx_xslt: '/xsl/dynarex.xsl',
        rss_xslt: '/xsl/feed.xsl',
        target_page: :page,
        target_xslt: '/xsl/page.xsl',
        local_media_path: '/home/user/media',
        url_media_path: 'http://media.yourwebsitehere.co.uk/'
      }.merge(options)


      @filepath, @timeline = dir, timeline

      @index = nil
      @hashtags = nil


      if hashtag_url then

        @hashtag_url = @options[:url_base] + hashtag_url.sub(/^\//,'')

        hashtag_path = File.join(dir, 'hashtag')
        tagdb = File.join(hashtag_path, 'index.db')
        FileX.mkdir_p File.dirname(tagdb)

        h = {hashtags: {id: '', tag: '', topic: '', noticeid: ''}}
        @hashtags = RecordxSqlite.new(tagdb, table: h )

      end
    end

    def incoming(topic, msg)

      a = topic.split('/')
      context = a.last.to_sym

      case context
      when :profile

        #update_attributes(:description, subtopic=a[-2], profile=msg)
        h = JSON.parse msg, symbolize_names: true
        update_profile(subtopic=a[-2], h)

      when :link
        puts 'we have a link' if @debug
        update_attributes(:link, subtopic=a[-2], link=msg)

      when :title

        update_attributes(:title, subtopic=a[-2], title=msg)

      when :image
        #puts 'we have an image'
        update_attributes(:image, subtopic=a[-2], title=msg)

      when :delete

        delete_notice(subtopic=a[-2], msg)

      when :json

        # JSON contains a message and 1 or more media files
        h = JSON.parse msg, symbolize_names: true
        puts 'h: ' + h.inspect if @debug

        subtopic = a[-2]

        t = Time.now
        id = t.to_i.to_s + t.strftime("%2N")

        filepath = File.join(@options[:local_media_path], 'images')

        a = h[:files].map.with_index do |f,i|

          # is f an Array object containing various sized images of the 1 file?
          a2 = f.is_a?(Array) ? f : [f]

          scale = a2.map do |imgfile|

            scale = imgfile[/(_\w+)\.\w+$/,1].to_s
            file = "%s%s%s" % [(id.to_i + i+1).to_s(36).reverse, scale, File.extname(imgfile)]
            dest = File.join(filepath, file)

            FileX.cp imgfile, dest
            FileX.chmod 0755, dest

            file

          end
          puts 'scale: ' + scale.inspect
          index = scale[2] ? 2 : (scale[1] ? 1 : 0)
          file1 = scale[index]

          dir = File.extname(file1) =~ /\.(?:jpg|png)/ ? 'images' : ''
          url = [@options[:url_media_path], dir, file1].join('/')

          href = [@options[:url_base].sub(/\/$/,''), subtopic, 'status', id,
                  'photo', (i+1).to_s ].join('/')
          # find the best y position for the image letterbox view
          pct = EasyImgUtils.new(a2[index]).best_viewport
          pct2 = (pct / 10.0).to_i * 10

          align = if pct < 35 then

            if pct < 10 then
              :top
            else
              'y' + pct2.to_s
            end

          elsif pct >= 70
            :bottom
          else
            #'y' + pct.to_s
            :center
          end

          {url: url, align: align}

        end


        card = if h[:card] then

          puts 'h[:card]: ' + h[:card].inspect
          puts 'a: ' + a.inspect

          if h[:card][:summary_large_image] then

            h[:card][:summary_large_image][:img] = a[2][:url] if a.any?
            h[:card]

          elsif h[:card][:summary]

            h[:card][:summary][:img] = a[0][:url] if a.any?
            h[:card]

          end

        elsif a.any?
          {images: a}
        end
        puts 'before build'
        #puts ('card: ' + card.inspect).debug

        h[:msg] += build(card) if card
        add_notice(subtopic, h[:msg].gsub('<','&lt;')\
                   .gsub('>','&gt;').gsub("\r",''), id,
                   (card ? card.to_json  : nil))

      else

        subtopic, id = a[1..-1]
        add_notice(subtopic, msg, id)

      end
    end

    private

    def add_notice(topic, raw_msg, raw_id=nil, card=nil)

      @log.info 'mns_subscriber/add_notice: active' if @log
      topic_dir = File.join(@filepath, 'u', topic)

      options = @options.clone
      options.delete :local_media_path
      options.delete :url_media_path

      notices = DailyNotices.new topic_dir, options.merge(identifier: topic,
                          title: topic.capitalize + ' daily notices', log: @log)

      t = Time.now
      id = (raw_id || t.to_i.to_s + t.strftime("%2N")).to_i

      # strip out any JSON from the end of the message
      msg, raw_json = raw_msg.split(/(?=\{.*)/)

      msg = ' ' if msg.nil?
      mtlite = MTLite.new(msg)

      desc = if mtlite.to_html(para: false) =~ /<\w+/ then
        mtlite.to_html(para: true, ignore_domainlabel:true)
      else
        mtlite.to_s
      end

      if @hashtag_url then

        tags = desc.scan(/(?<= #)\w+/)

        desc.gsub!(/ [#\$][a-zA-Z]\w+/) do |rawx|

          x = rawx.lstrip
          baseurl = x[0] == '#' ? @hashtag_url : 'search?q='
          url = baseurl + CGI.escape(x.sub(/^#/,''))
          " <a href='%s'>%s</a>" % [url, x]

        end

        # add the record to the database
        tags.each do |tag|

          t = Time.now
          id2 = (t.to_i.to_s + t.strftime("%2N")).to_i
          h = {id: id2, tag: tag, topic: topic, noticeid: id}

          @hashtags.create h if @hashtags

        end

      end

      title = mtlite.to_s.lines.first.chomp
      title = title[0..136] + ' ...' if title.length > 140

      h = {
        title: title,
        description: desc,
        topic: topic,
        card: card
      }
      #puts 'inside add_notice h: ' + h.inspect
      return_status = notices.add(item: h, id: id.to_s)
      #puts 'return_status: ' + return_status.inspect

      return if return_status == :duplicate

      rxnotices = RecordxSqlite.new(File.join(topic_dir, 'notices.db'),
        table: {notices: {id: 0, description: '', message: ''}})

      begin
        rxnotices.create id: id.to_s, description: desc, message: msg
      rescue
        puts 'warning: rxnotices.create -> ' + ($!).inspect
      end

      if raw_json then

        record = JSON.parse(raw_json)
        index = RecordxSqlite.new(File.join(topic_dir, 'index.db'),
          table: {items: record})
        index.create record

        update_index_xml(index, topic_dir)

      end

      @sps.notice "%s/add: %s/status/%s"  % [@timeline, topic, id] if @timeline

      sleep 0.3

    end

    def delete_notice(topic, msg)

      topic_dir = File.join(@filepath, topic)

      id = msg.to_i

      feed = DailyNotices.new topic_dir, log: @log
      feed.delete id

      notices = RecordxSqlite.new(File.join(topic_dir, 'notices.db'),
                                  table: 'notices')
      notices.delete id

      indexdb = File.join(topic_dir, 'index.db')

      if File.exists? indexdb then

        index = RecordxSqlite.new(indexdb, table: 'items')
        index.delete id
        update_index_xml(index, topic_dir)
      end

    end

    # builds the HTML for a given card
    #
    def build(card)
      puts 'inside build'

      #return card.inspect
      #next unless card.is_a? Hash

      if card.is_a? Hash then

        card2 = case card.keys.first
        when :images

          card[:images].map.with_index do |img, i|

            "<img class='img1' src='%s'/>" % img[:url]

          end.join

        when :summary_large_image

          h2 = card[:summary_large_image]

          rawdesc = h2[:desc]

          desc = rawdesc.length > 147 ? rawdesc[0..147] + '...' : rawdesc
          site = h2[:url][/https?:\/\/([^\/]+)/,1].sub(/^www\./,'')
          title = h2[:title]
          img = h2[:img]
          url = h2[:url]

          # The following Card HTML template is for use with the RSS feed.
          # The actual HTML template for the card is rendered dynamically
          # from the web server.
"
<div class='card'><a href='#{url}' target='_blank'>" +
    "<div class='top-crop center'><img src='#{img}'/></div>" +
    "<span class='title'>#{title}</span></a><p>#{desc}</p>" +
    "<span class='link'><span class='linkurl'>#{site}</span></span></div>"

        when :summary

          h2 = card[:summary]
          puts 'h2: ' + h2.inspect
          rawdesc = h2[:desc]

          desc = rawdesc.length > 120 ? rawdesc[0..120] + '...' : rawdesc
          site = h2[:url][/https?:\/\/([^\/]+)(?=\/)/,1].sub(/^www\./,'')
          title = h2[:title]
          img = h2[:img]
          url = h2[:url]

          # The following Card HTML template is for use with the RSS feed.
          # The actual HTML template for the card is rendered dynamically
          # from the web server.

"<div class='card2'><a href='#{url}' target='_blank'><div><div id='col1'>" +
    "<img src='#{img}'></div><div id='col2'><div id='content'>" +
    "<span class='title'>#{title}</span><span class='desc'>#{desc}</span>" +
    "<span class='link'><span class='linkurl'>#{site}</span></span></div>" +
    "</div></div></a></div>"

        end
      end

    end

    def update_index_xml(index, topic_dir)

      # create the index.xml file

      a = index.order(:desc).first(15)
      a2 = a.map {|x| h = x.to_h; id = h.delete(:id); {item_id: id}.merge(h)}

      dx = Dynarex.new
      dx.import a2
      dx.order ='descending'

      dx.save File.join(topic_dir, 'index.xml')

    end

    def update_attributes(attribute, topic, value)

      topic_dir = File.join(@filepath, topic)
      notices = DailyNotices.new topic_dir, @options.merge(identifier: topic)
      notices.method((attribute.to_s + '=').to_sym).call(value)
      notices.save

    end

    def update_profile(topic, h)

      topic_dir = File.join(@filepath, topic)
      notices = DailyNotices.new topic_dir, @options.merge(identifier: topic)

      valid_keys = %i(title identifier image bio location website banner_image)

      h.each_pair do |key, value|

        next unless valid_keys.include? key

        attribute = key.to_s
        notices.method((attribute + '=').to_sym).call(value)

      end

      notices.save

    end


  end

  class Client < SPSSub

    def initialize(host: 'sps', port: 59000, dir: '.', options: {},
                  timeline: nil, log: nil, hashtag_url: nil)

      @log = log
      log.info 'mns_subscriber/initialize: active' if log
      @nm = NoticeMgr.new(self, dir: dir, options: options, timeline: timeline,
                    hashtag_url: hashtag_url, debug: true)

      super(host: host, port: port, log: log)

    end

    def subscribe(topic='notice/*')
      super(topic)
    end

    private

    def ontopic(topic, msg)

      @log.info 'mns_subscriber/ontopic: topic: ' + topic.inspect if @topic

      a = topic.split('/')
      #puts "%s: %s %s"  % [topic, Time.now.to_s, msg.inspect]

      @nm.incoming topic, msg

    end

  end

end
