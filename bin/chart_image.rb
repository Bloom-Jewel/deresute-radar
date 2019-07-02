#!/usr/bin/env ruby

require_relative 'chart_parser'
require_relative 'chart_bpm'
require 'rmagick'

module ChartAnalyzer; class Image
  # fixed beat amount per measure
  MEASURE_BEAT     =   4
  MEASURE_SPLIT    =   8
  
  # defines the margin through the actual image
  MARGIN_IMAGE     =  32 # ALL
  
  # the measure column margin for MEASURE# on left and BPM# on right side
  MARGIN_LINESET   =  32 # LEFT RIGHT
  
  BEAT_HEIGHT      =  48
  BEAT_WIDTH       = 144
  
  PATH_WIDTH       =   6
  BENT_RANGE       =   0.50
  BENT_SIZE        =   0.10
  
  IMAGE_FLICKS     = [
    Magick::Image.new(17,17){ self.background_color='none' }.tap { |img|
      dr = Magick::Draw.new
      
      dr.stroke('black')
      dr.fill('rgb(48,48,255)')
      dr.circle(8,8,8,2)
      
      dr.stroke('none')
      dr.fill('white')
      dr.rectangle(4,7,8,9)
      dr.polygon(8,5,12,8,8,11)
      
      dr.draw(img)
    },
    Magick::Image.new(17,17){ self.background_color='none' }.tap { |img|
      dr = Magick::Draw.new
      
      dr.stroke('black')
      dr.fill('rgb(48,48,255)')
      dr.circle(8,8,8,2)
      
      dr.stroke('none')
      dr.fill('white')
      dr.polygon(6,5,10,8,6,11)
      
      dr.draw(img)
    },
  ]
  IMAGE_NOTES      = [
    Magick::Image.new(17,17){ self.background_color='none' }.tap { |img|
      dr = Magick::Draw.new
      
      dr.stroke('black')
      dr.fill('rgb(255,48,48)')
      dr.circle(8,8,8,2)
      
      dr.draw(img)
    },
    Magick::Image.new(17,17){ self.background_color='none' }.tap { |img|
      dr = Magick::Draw.new
      
      dr.stroke('black')
      dr.fill('rgb(255,216,48)')
      dr.circle(8,8,8,2)
      
      dr.stroke('none')
      dr.fill('white')
      dr.circle(8,8,8,6)
      
      dr.draw(img)
    },
    Magick::Image.new(17,17){ self.background_color='none' }.tap { |img|
      dr = Magick::Draw.new
      
      dr.stroke('black')
      dr.fill('rgb(160,48,255)')
      dr.circle(8,8,8,2)
      
      dr.stroke('white')
      dr.fill('none')
      dr.line(3,8,6,8)
      dr.circle(8,8,8,6)
      dr.line(10,8,13,8)
      
      dr.draw(img)
    },
    IMAGE_FLICKS[0],
  ]
  IMAGE_CHUUNITHM_NOTES = {}.instance_exec do
    stretch = ->(nw,i){
      return if nw < 17
      return unless [0,1,2].include?(i)
      img = Magick::Image.new(nw,17){self.background_color='none'}
      pcs = []
      
      src = IMAGE_NOTES[i]
      ->(){
        a = src.dispatch 0,0,8,17,'RGBA'
        b = Magick::Image.constitute 8,17,'RGBA',a
        
        a.clear
        pcs << b
      }.call
      ->(){
        a = src.dispatch 9,0,8,17,'RGBA'
        b = Magick::Image.constitute 8,17,'RGBA',a
        
        a.clear
        pcs << b
      }.call
      ->(){
        a = src.dispatch 8,0,1,17,'RGBA'
        b = Magick::Image.constitute 1,17,'RGBA',a
        b.resize!(nw - 16,17)
        
        a.clear
        pcs << b
      }.call
      pcs.shift.tap do |b|
        img.composite!(b,0,0,Magick::OverCompositeOp)
        b.destroy!
      end
      pcs.shift.tap do |b|
        img.composite!(b,nw-8,0,Magick::OverCompositeOp)
        b.destroy!
      end
      pcs.shift.tap do |b|
        img.composite!(b,8,0,Magick::OverCompositeOp)
        b.destroy!
      end
      
      img
    }
    flick_stretch = ->(nw,n){
      return if nw < 17
      Magick::Image.new(nw,17){self.background_color='none'}.tap do |img|
        dr = Magick::Draw.new
        
        dr.stroke('black')
        dr.fill('rgb(48,48,255)')
        dr.roundrectangle(2, 2, nw-4, 13, 8, 8)
        
        dr.stroke('none')
        dr.fill('white')
        s = nw - 17
        n.times do |i|
          x = 8 + (Rational(i,[n.pred,1].max) * s).round
          dr.polygon(x-2,5,x+2,8,x-2,11)
        end
        
        dr.draw(img)
      end
    }
    1.upto(15) do |i|
      s = 17+(i.pred*13.5).round
      store i, [stretch.call(s,0),stretch.call(s,1),stretch.call(s,2),flick_stretch.call(s,2 * i - 1)]
    end
    self
  end
  
  # Flag to prevent file replacement
  IMAGE_LATEST       = ENV.key?('CHART_LATEST')
  CURRENT_IMAGE_MODE = [
                         ENV.fetch('CHART_ORIENTATION','').tap { |mode|
                           if mode.empty? || !/^\d+$/.match(mode) then
                             fail "CHART_ORIENTATION value must be a non-negative integer!"
                           end
                         }.to_i
                       ].pop
  # Flag to modify image printing
  IMAGE_MODE_TOP     = 1 # Deprecated
  IMAGE_MODE_MIRROR  = 2
  IMAGE_MODE_BOTH    = 6
  
  CONFIGURATION      = {
    normal: {allow_mirror:  true, field_size: 10, column_count:  5, height_scale: 1.0, object_height: 1.0},
    casual: {allow_mirror: false, field_size: 10, column_count:  5, height_scale: 1.0, object_height: 1.0},
    chuuni: {allow_mirror:  true, field_size: 15, column_count: 15, height_scale: 1.0, object_height: 0.5},
    apfool: {allow_mirror: false, field_size: 10, column_count:  5, height_scale: 1.0, object_height: 1.0},
  }
  CONFIG_DEFAULT     = CONFIGURATION[:normal].dup.freeze
  
  include FinalClass
  def initialize(song_id:,diff_id:)
    @song_id, @diff_id = [
      [[(Integer(song_id,10) rescue 0),999].min,0].max,
      [[(Integer(diff_id,10) rescue 0), 99].min,0].max
    ]

    @parser   = Parser.new(song_id: @song_id, diff_id: @diff_id)
    @chart    = @parser.parse
    @bpm      = AutoBPM.new(song_id: @song_id)
    @color    = 0
    @bpm.get_bpm
    
    if @song_id > 900 then
      @type   = :apfool
    elsif @diff_id.between?( 1, 9) then
      @type   = :normal
    elsif @diff_id.between?(11,19) then
      @type   = :casual
    elsif @diff_id.between?(21,29) then
      @type   = :chuuni
    else
      fail TypeError, "unknown chart type"
    end
    @config   = CONFIGURATION[@type].dup
    @image    = Magick::ImageList.new
    process_config
  end
  
  private
  def process_config
    @config.update({
      beat_width:  BEAT_WIDTH * @config[:field_size] / CONFIG_DEFAULT[:field_size],
      beat_height: (BEAT_HEIGHT * @config[:height_scale]).round,
    })
  end
  
  def time_to_measure
    return unless BaseNote.timing_mode == :exact
    
    time_table = {}
    @chart.notes.each do |note_id, note|
      time_table.store note.object_id, @bpm.mapped_time[note.time]
    end
    @chart.raws.each do |cmd_id, raw|
      raw[:at_me] = @bpm.mapped_time[ raw[:at] ]
    end
    
    BaseNote.timing_mode = :rhythmic
    @chart.notes.each do |note_id, note|
      new_time = time_table.delete note.object_id
      note.time = new_time
    end
    
    true
  end
  
  def measure_to_time
    return unless BaseNote.timing_mode == :rhythmic
    
    time_table = {}
    @chart.notes.each do |note_id, note|
      time_table.store note.object_id, note.time.to_r
    end
    
    BaseNote.timing_mode = :exact
    @chart.notes.each do |note_id, note|
      old_beat  = time_table.delete note.object_id
      note.time = @bpm.mapped_time.find { |time, beat| old_beat == beat }.first
    end
    
    true
  end
  
  def generate_measures
    chart_notes    = @chart.notes.values
    chart_holds    = @chart.holds.values
    chart_paths    = @chart.slides.values
    chart_commands = @chart.raws.values
    
    hold_notes     = chart_holds.map { |holds| holds.each.to_a }.flatten.select { |note| Deresute::TapNote === note }
    
    is_hold        = ->(note) {
      hold_notes.include?(note)
    }
      
    measure_list   = chart_notes.map(&:time).uniq
    measure_start  = (measure_list.min.to_r/MEASURE_BEAT).floor*MEASURE_BEAT
    measure_finish = (measure_list.max.to_r/MEASURE_BEAT).ceil* MEASURE_BEAT + MEASURE_BEAT
    split_size     = MEASURE_BEAT * MEASURE_SPLIT
    
    basis_width    = MARGIN_IMAGE + MARGIN_LINESET + @config[:beat_width] + MARGIN_LINESET + MARGIN_IMAGE
    basis_height   = MARGIN_IMAGE + @config[:beat_height] * measure_finish + MARGIN_IMAGE
    
    # Split Size - segment split images, every 4 beats
    split_width    = MARGIN_LINESET + @config[:beat_width] + MARGIN_LINESET
    split_height   = MARGIN_IMAGE + @config[:beat_height] * split_size + MARGIN_IMAGE
    
    # Combined Size - segment joining
    final_width    = MARGIN_IMAGE + split_width * Rational(measure_finish,split_size).ceil + MARGIN_IMAGE
    final_height   = split_height
    
    IMAGE_NOTES.each_with_index do |sprite,index|
      sprite.write(File.join(ENV['HOME'],'Documents','rmagick',"%02d.png"%[index]))
    end if false
    
    Magick::Image.new(basis_width,basis_height) { self.background_color = 'none' }.tap do |field_image|
      Magick::Draw.new.tap do |field_draw|
        field_draw.translate(MARGIN_IMAGE,MARGIN_IMAGE)
        chart_state = []
        chart_commands.each do |command|
          case command[:type]
          when 200,201,202
            #chart_state << {command: :color, color: command[:type] - 199, meas: command[:at_me]}
          when 210,211
            #field_draw.text_align(Magick::RightAlign)
            #field_draw.stroke('maroon')
            #field_draw.fill('maroon')
            #field_draw.text(MARGIN_LINESET + @config[:beat_width], (@config[:beat_height])
            is_loop = command[:type] == 210
            chart_state << {command: :loop, loop: is_loop, meas: command[:at_me]}
          when 92
            chart_state << {command: :stop, meas: command[:at_me]}
          end
        end
        chart_state.select{|c| [:color,:stop].include?(c[:command]) }.each_cons(2) do |state_cur,state_next|
          color = ['#FFFFFF20','#FF006320','#006BFF20','#FFA90720'].at(state_cur[:color])
          field_draw.stroke('none')
          field_draw.fill(color)
          yf = @config[:beat_height]*([measure_finish - state_next[:meas],0].max).floor
          yt = @config[:beat_height]*(measure_finish - state_cur[:meas]).floor
          field_draw.rectangle(MARGIN_LINESET,yf,MARGIN_LINESET+@config[:beat_width],yt)
        end
        
        field_draw.text_align(Magick::LeftAlign)
        chart_state.select{|c| [:loop,:stop].include?(c[:command]) }.each_cons(2) do |state_cur,state_next|
          color = state_cur[:loop] ? '#FF008860' : 'none'
          field_draw.stroke('none')
          field_draw.fill(color)
          yf = @config[:beat_height]*([measure_finish - state_next[:meas],0].max).floor
          yt = @config[:beat_height]*(measure_finish - state_cur[:meas]).floor
          field_draw.rectangle(MARGIN_LINESET,yf,MARGIN_LINESET+@config[:beat_width]*1/4,yt)
          
          if state_cur[:loop] then
            color = '#800000'
            text  = 'FEVER HERE'
          else
            color = '#C00000'
            text  = 'FEVER STOP'
          end
          field_draw.fill(color)
          field_draw.stroke(color)
          field_draw.font_size(8)
          field_draw.stroke_width(0.5)
          field_draw.text(MARGIN_LINESET + 2, yt - 4, text)
        end
        
        field_draw.fill('none')
        field_draw.stroke('black')
        field_draw.stroke_width(4)
        field_draw.rectangle(MARGIN_LINESET,0,MARGIN_LINESET+@config[:beat_width],@config[:beat_height] * measure_finish)
        
        field_draw.text_align(Magick::RightAlign)
        field_draw.fill('black')
        0.upto(measure_finish - 1) do |beat|
          if (beat % 4).zero? then
            field_draw.stroke_width(1)
            field_draw.font_size(16)
            field_draw.text(MARGIN_LINESET - 2, @config[:beat_height]*(measure_finish - beat) + 4, "%03d" % [(beat / 4).succ])
          end
          
          field_draw.stroke_width((beat % 4).zero? ? 4 : 2)
          field_draw.line(MARGIN_LINESET,@config[:beat_height]*beat,MARGIN_LINESET+@config[:beat_width],@config[:beat_height]*beat)
        end
        
        field_draw.text_align(Magick::LeftAlign)
        field_draw.stroke_width(1)
        field_draw.stroke('red')
        field_draw.fill('red')
        @bpm.timing_set.each do |measure, amount|
          field_draw.text(MARGIN_LINESET + @config[:beat_width] - 14, (@config[:beat_height]*(measure_finish - measure)).floor + 4, "%05.1f" % [amount])
        end
        #field_draw.composite(MARGIN_IMAGE,MARGIN_IMAGE,basis_width - MARGIN_IMAGE * 2,basis_height - MARGIN_IMAGE * 2,basis_image)
        #field_draw.translate(MARGIN_IMAGE,MARGIN_IMAGE)
        field_draw.draw(field_image)
      end
      
      is_nomirr = (CURRENT_IMAGE_MODE & IMAGE_MODE_MIRROR).zero? || ((CURRENT_IMAGE_MODE & IMAGE_MODE_BOTH) <=> IMAGE_MODE_BOTH).zero?
      is_domirr = !(CURRENT_IMAGE_MODE & IMAGE_MODE_MIRROR).zero?
      im_mode   = CURRENT_IMAGE_MODE.to_s(2)
      2.times do |nth|
        next if nth.even? && !is_nomirr
        next if nth.odd?  && !(is_domirr && @config[:allow_mirror])
        if im_mode.count('1') == 1
          basis_image = field_image
        else
          basis_image = field_image.dup
        end
        coord_convert = ->(lane,time,width=1) {
          lane += Rational(width - 1,2.0).to_f if width > 1
          lane = @config[:column_count].succ - lane if nth.odd?
          [MARGIN_LINESET + (@config[:beat_width] * Rational(lane,@config[:column_count].succ)), (@config[:beat_height] * (measure_finish - time.to_r))].map(&:round)
          
        }
        # 1.upto(15) do |i| p coord_convert.call(i,10.0) end
        
        note_convert  = ->(note,center:false) {
          coord_convert.call(note.pos, note.time, center ? note.width : 1)
        }
        
        Magick::Draw.new.tap do |path_set|
          path_set.translate(MARGIN_IMAGE,MARGIN_IMAGE)
          path_set.fill('none')
          path_set.stroke('rgb(180,180,180)')
          path_set.stroke_opacity('80%')
          path_set.stroke_width(PATH_WIDTH)
          
          chart_holds.each do |hold|
            start, finish = hold[0,1]
            path_set.line *(note_convert.call(start,center:true)+note_convert.call(finish,center:true))
          end
          
          coords = []
          sharpness = 2
          chart_paths.each do |path|
            path.each_cons(2) do |(start,finish)|
              #coords.pop(sharpness << 1) # remove previous anchor
              duration  = (finish.time - start.time).to_r
              is_slide  = Deresute::SlideNote === start
              is_long   = duration >= 2
              is_cut    = !is_slide && duration >= 16
              is_para   = (finish.pos <=> start.pos).zero?
              
              is_bent   = is_slide && is_long && !is_cut && !is_para
              coords.push *(note_convert.call(start,center:true))  # Prepare start anchor
              if is_bent then
                pos          = [start,finish].map{|note| note.pos + Rational(note.width - 1,2).to_f}
                is_early     = true
                between_time = chart_notes.select { |note| note.time > start.time && note.time < finish.time }
                
                midway_notes = between_time.select { |note| note.pos == start.pos }
                is_early    &= !midway_notes.empty?
                midway_notes.clear
                
                between_time.clear
                
                pos_ratio    = (pos.last - pos.first).abs
                bent_range   = BENT_RANGE + pos_ratio * BENT_SIZE
                if is_early
                  coords.push *(coord_convert.call(pos.last - (pos.last - pos.first) * 0.2, start.time.to_r + (bent_range - BENT_SIZE * 2)) * sharpness)
                  coords.push *(coord_convert.call(pos.last, start.time.to_r + (bent_range - BENT_SIZE)))
                  coords.push *(coord_convert.call(pos.last, start.time.to_r + bent_range) * sharpness)
                else
                  coords.push *(coord_convert.call(pos.first, finish.time.to_r - bent_range) * sharpness)
                  coords.push *(coord_convert.call(pos.first, finish.time.to_r - (bent_range - BENT_SIZE)))
                  coords.push *(coord_convert.call(pos.first + (pos.last - pos.first) * 0.2, finish.time.to_r - (bent_range - BENT_SIZE * 2)) * sharpness)
                end
                pos.clear
              end
              coords.push *(note_convert.call(finish,center:true)) # Put temporary anchor (unless final)
              if !is_cut then
                if coords.size > 4 && coords.size % 2 == 0 then
                  path_set.bezier *coords
                elsif coords.size == 4
                  path_set.line   *coords
                else
                  $stderr.puts "Invalid Coordinate Size"
                end
              end
              coords.clear
            end
          end
          
          path_set.draw(basis_image)
        end
        
        chart_notes.each do |note|
          flip  = false
          type  = case note
                  when Deresute::TapNote
                    is_hold.call(note) ? 2 : 1
                  when Deresute::FlickNote
                    flip = note.param == 1 ? true : false
                    flip = !flip if nth.odd?
                    4
                  when Deresute::SlideNote
                    3
                  end
          case @type
          when :chuuni
            image = IMAGE_CHUUNITHM_NOTES[note.width][type.pred].dup
          else
            image = IMAGE_NOTES[type.pred].dup
          end
          ->(){
            return if (@config[:object_height] - 1.0).abs <= 1e-6
            h_orig = image.rows
            h_new  = (h_orig * @config[:object_height])
            y_off  = (h_orig - h_new) / 2
            image.resize!(image.columns,h_new.ceil)
            image2 = Magick::Image.new(image.columns,h_orig.round){self.background_color = 'none'}
            
            image2.composite!(image, 0, (y_off).ceil, Magick::OverCompositeOp)
            
            image.destroy!
            image = image2
          }.call
          image = image.flop if flip
          if note.is_a?(Deresute::TapColorNote) then
            ucolor = ['#FFFFFF','#FF0063','#006BFF','#FFA907'].at(note.color % 4)
            #image2 = image.modulate(110,0)
            image2 = image.color_flood_fill(image.pixel_color(8,8),ucolor,8,8,Magick::FloodfillMethod)
            image.destroy!
            image = image2
          end
          basis_image.composite!(image, *note_convert.call(note).map { |c| c + MARGIN_IMAGE - 8 }, Magick::OverCompositeOp)
          image.destroy!
        end
        
        Magick::Image.new(final_width,final_height + @config[:beat_height] * 1) { self.background_color = 'white' }.tap do |final_image|
          0.step(Rational(measure_finish,split_size).ceil * split_size, split_size).each_with_index do |measure, column|
            if false
              y_off = ((column  * split_size - 0.5) * @config[:beat_height]).round
            else
              y_off = ((measure_finish - split_size * (column + 1) - 0.5) * @config[:beat_height]).round
            end
            sp_w  = MARGIN_LINESET * 2 + @config[:beat_width]
            sp_h  = (split_size + 1) * @config[:beat_height]
            
            pix   = basis_image.dispatch(MARGIN_IMAGE, MARGIN_IMAGE + y_off, sp_w, sp_h,'RGBA')
            spl   = Magick::Image.constitute(sp_w, sp_h, 'RGBA', pix)
            final_image.composite!(spl, MARGIN_IMAGE + (column) * sp_w, MARGIN_IMAGE, Magick::OverCompositeOp)
            pix.clear
            spl.destroy!
            break if y_off < 0
          end
          
          dir     = File.join('chart.image')
          ctime   = Time.now
          fn      = File.join(dir,"%03d_%02d.%s.%d.png")
          fmode   = []
          fmode  << [:NM,:MR][nth % 2]
          
          forepl  = Dir[File.join(dir,"%03d_%02d.*.png" % [@song_id,@diff_id])]
          frepl   = Dir[File.join(dir,"%03d_%02d.%s.*.png" % [@song_id,@diff_id,fmode*''])]
          if frepl.empty? && !forepl.empty? then
            # force renaming to old convention
            forepl.each do |f|
              fm = /^(.+)\/(\d{3})[_](\d)[.](\d+)[.]png$/.match(f)
              if !fm.is_a?(Array) || fm.size != 4
                p fm
                next
              end
              fp = "%s/%s_%s.NM.%s.png" % fm.to_a[1..-1]
              File.rename(f,fp)
              frepl.push fp
            end
          end if nth == 0
          # modes :
          # - NM  : bottom/up, no mirror (v2 default)
          # - MR  : bottom/up, mirror
          # - TD  : top/down, no mirror (v1 default)
          # - TDMR: top/down, mirror
          if IMAGE_LATEST || frepl.empty?
            final_image.write(fn % [@song_id, @diff_id, fmode*'', ctime])
          else
            fn.replace frepl.max_by{|f|File.mtime(f)}
            final_image.write(fn)
          end
          
          final_image.destroy!
        end
        
        basis_image.destroy!
      end
        
      field_image.destroy!
    end
  end
  
  public
  def generate
    time_to_measure
    generate_measures
    measure_to_time
  end
  
  def method_missing(m,*a,&b)
    if instance_variable_defined?("@#{m}") then
      self.class.class_exec { define_method("#{m}") { instance_variable_get("@#{m}") } }
      send m
    else
      super(m,*a,&b)
    end
  end
  def self.main(*argv)
    new(song_id: argv.shift, diff_id: argv.shift).instance_exec { generate }
  end if is_main_file
end; end

def main(*argv); ChartAnalyzer::Image.main(*argv); end if is_main_file

