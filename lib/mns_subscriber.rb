#!/usr/bin/env ruby

# file: mns_subscriber.rb


require 'mtlite'
require 'sps-sub'
require 'daily_notices'
require 'recordx_sqlite'


class MNSSubscriber < SPSSub

  def initialize(host: 'sps', port: 59000, dir: '.', options: {}, 
                 timeline: nil, log: nil, hashtag_url: nil)
    
    @log = log
    log.info 'mns_subscriber/initialize: active' if log
    
    # note: a valid url_base must be provided
    
    @options = {
      url_base: 'http://yourwebsitehere.co.uk/', 
      dx_xslt: '/xsl/dynarex.xsl', 
      rss_xslt: '/xsl/feed.xsl', 
      target_page: :page, 
      target_xslt: '/xsl/page.xsl'      
    }.merge(options)

    super(host: host, port: port, log: log)
    @filepath, @timeline = dir, timeline
    
    @index = nil
    @hashtags = nil
    
    
    if hashtag_url then
      
      @hashtag_url = @options[:url_base] + hashtag_url.sub(/^\//,'')      
      
      hashtag_path = File.join(dir, 'hashtag')
      tagdb = File.join(hashtag_path, 'index.db')
      FileUtils.mkdir_p File.dirname(tagdb)
      
      h = {hashtags: {id: '', tag: '', topic: '', noticeid: ''}}
      @hashtags = RecordxSqlite.new(tagdb, table: h )            

    end

  end

  def subscribe(topic='notice/*')
    super(topic)
  end

  private

  def ontopic(topic, msg)
    
    @log.info 'mns_subscriber/ontopic: topic: ' + topic.inspect if @topic

    a = topic.split('/')
    puts "%s: %s %s"  % [topic, Time.now.to_s, msg.inspect]
    
    
    case a.last.to_sym
      
    when :profile
          
      update_attributes(:description, subtopic=a[-2], profile=msg)

    when :link
          
      update_attributes(:link, subtopic=a[-2], link=msg)
      
    when :title
          
      update_attributes(:title, subtopic=a[-2], title=msg)
      
    when :image
          
      update_attributes(:image, subtopic=a[-2], title=msg)      
      
    when :delete
      
      delete_notice(subtopic=a[-2], msg)
      
    else
      
      subtopic, id = a[1..-1]
      add_notice(subtopic, msg, id)
      
    end    

  end

  def add_notice(topic, raw_msg, raw_id=nil)

    @log.info 'mns_subscriber/add_notice: active' if @log
    topic_dir = File.join(@filepath, topic)
    notices = DailyNotices.new topic_dir, @options.merge(identifier: topic, 
                        title: topic.capitalize + ' daily notices', log: @log)

    t = Time.now
    id = (raw_id || t.to_i.to_s + t.strftime("%2N")).to_i
    
    # strip out any JSON from the end of the message
    msg, raw_json = raw_msg.split(/(?=\{.*)/) 
    
    mtlite = MTLite.new(msg)
    
    desc = if mtlite.to_html(para: false) =~ /<\w+/ then
      mtlite.to_html(para: true, ignore_domainlabel:true)
    else
      mtlite.to_s
    end
    
    if @hashtag_url then

      tags = desc.scan(/(?<=#)\w+/)
      
      desc.gsub!(/#\w+/) do |x| 
        "<a href='%s%s'>%s</a>" % [@hashtag_url, x[1..-1], x]
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
      topic: topic
    }

    return_status = notices.add(item: h, id: id.to_s)
    
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
    
    self.notice "%s/add: %s/status/%s"  % [@timeline, topic, id] if @timeline
    
    sleep 0.3
    
  end
  
  def delete_notice(topic, msg)
    
    topic_dir = File.join(@filepath, topic)
    
    notices = RecordxSqlite.new(File.join(topic_dir, 'notices.db'), 
                                table: 'notices')
    id = msg.to_i
    notices.delete id
    
    indexdb = File.join(topic_dir, 'index.db')
    
    if File.exists? indexdb then
      
      index = RecordxSqlite.new(indexdb, table: 'items')
      index.delete id
      update_index_xml(index, topic_dir)
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

end
