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
  
  BEAT_WIDTH       = 144
  BEAT_HEIGHT      =  32
  
  PATH_WIDTH       =   6
  BENT_RANGE       =   0.50
  BENT_SIZE        =   0.10
  
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
  ]
  
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
  
  include FinalClass
  def initialize(song_id:,diff_id:)
    @song_id, @diff_id = [
      [[(Integer(song_id,10) rescue 0),999].min,0].max,
      [[(Integer(diff_id,10) rescue 0),  9].min,0].max
    ]

    @parser   = Parser.new(song_id: @song_id, diff_id: @diff_id)
    @chart    = @parser.parse
    @bpm      = AutoBPM.new(song_id: @song_id)
    @color    = 0
    @bpm.get_bpm
    
    @image    = Magick::ImageList.new
  end
  
  private
  def time_to_measure
    return unless BaseNote.timing_mode == :exact
    
    time_table = {}
    @chart.notes.each do |note_id, note|
      time_table.store note.object_id, @bpm.mapped_time[note.time]
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
    
    hold_notes     = chart_holds.map { |holds| holds.each.to_a }.flatten.select { |note| Deresute::TapNote === note }
    
    is_hold        = ->(note) {
      hold_notes.include?(note)
    }
      
    measure_list   = chart_notes.map(&:time).uniq
    measure_start  = (measure_list.min.to_r/MEASURE_BEAT).floor*MEASURE_BEAT
    measure_finish = (measure_list.max.to_r/MEASURE_BEAT).ceil* MEASURE_BEAT + MEASURE_BEAT
    split_size     = MEASURE_BEAT * MEASURE_SPLIT
    
    basis_width    = MARGIN_IMAGE + MARGIN_LINESET + BEAT_WIDTH + MARGIN_LINESET + MARGIN_IMAGE
    basis_height   = MARGIN_IMAGE + BEAT_HEIGHT * measure_finish + MARGIN_IMAGE
    
    # Split Size - segment split images, every 4 beats
    split_width    = MARGIN_LINESET + BEAT_WIDTH + MARGIN_LINESET
    split_height   = MARGIN_IMAGE + BEAT_HEIGHT * split_size + MARGIN_IMAGE
    
    # Combined Size - segment joining
    final_width    = MARGIN_IMAGE + split_width * Rational(measure_finish,split_size).ceil + MARGIN_IMAGE
    final_height   = split_height
    
    IMAGE_NOTES.each_with_index do |sprite,index|
      sprite.write(File.join(ENV['HOME'],'Documents','rmagick',"%02d.png"%[index]))
    end if false
    
    Magick::Image.new(basis_width,basis_height) { self.background_color = 'none' }.tap do |field_image|
      Magick::Draw.new.tap do |field_draw|
        field_draw.fill('none')
        field_draw.stroke('black')
        field_draw.stroke_width(4)
        
        field_draw.translate(MARGIN_IMAGE,MARGIN_IMAGE)
        field_draw.rectangle(MARGIN_LINESET,0,MARGIN_LINESET+BEAT_WIDTH,BEAT_HEIGHT * measure_finish)
        
        field_draw.text_align(Magick::RightAlign)
        field_draw.fill('black')
        0.upto(measure_finish - 1) do |beat|
          if (beat % 4).zero? then
            field_draw.stroke_width(1)
            field_draw.font_size(16)
            field_draw.text(MARGIN_LINESET - 2, BEAT_HEIGHT*(measure_finish - beat) + 4, "%03d" % [(beat / 4).succ])
          end
          
          field_draw.stroke_width((beat % 4).zero? ? 4 : 2)
          field_draw.line(MARGIN_LINESET,BEAT_HEIGHT*beat,MARGIN_LINESET+BEAT_WIDTH,BEAT_HEIGHT*beat)
        end
        
        field_draw.text_align(Magick::LeftAlign)
        field_draw.stroke_width(1)
        field_draw.stroke('red')
        field_draw.fill('red')
        @bpm.timing_set.each do |measure, amount|
          field_draw.text(MARGIN_LINESET + BEAT_WIDTH - 14, (BEAT_HEIGHT*(measure_finish - measure)).floor + 4, "%05.1f" % [amount])
        end
        
        #field_draw.composite(MARGIN_IMAGE,MARGIN_IMAGE,basis_width - MARGIN_IMAGE * 2,basis_height - MARGIN_IMAGE * 2,basis_image)
        #field_draw.translate(MARGIN_IMAGE,MARGIN_IMAGE)
        field_draw.draw(field_image)
      end
      
      is_nomirr = (CURRENT_IMAGE_MODE & IMAGE_MODE_MIRROR).zero? || ((CURRENT_IMAGE_MODE & IMAGE_MODE_BOTH) <=> IMAGE_MODE_BOTH).zero?
      is_domirr = !(CURRENT_IMAGE_MODE & IMAGE_MODE_MIRROR).zero?
      2.times do |nth|
        next if nth.even? && !is_nomirr
        next if nth.odd?  && !is_domirr
        basis_image = field_image.dup
        coord_convert = ->(lane,time) {
          lane = 6 - lane if nth.odd?
          [MARGIN_LINESET + (BEAT_WIDTH * Rational(lane,6)), (BEAT_HEIGHT * (measure_finish - time.to_r))].map(&:round)
        }
        
        note_convert  = ->(note) {
          coord_convert.call(note.pos, note.time)
        }
        
        Magick::Draw.new.tap do |path_set|
          path_set.translate(MARGIN_IMAGE,MARGIN_IMAGE)
          path_set.fill('none')
          path_set.stroke('rgb(180,180,180)')
          path_set.stroke_opacity('80%')
          path_set.stroke_width(PATH_WIDTH)
          
          chart_holds.each do |hold|
            start, finish = hold[0,1]
            path_set.line *(note_convert.call(start)+note_convert.call(finish))
          end
          
          coords = []
          sharpness = 4
          chart_paths.each do |path|
            path.each_cons(2) do |(start,finish)|
              coords.pop(sharpness << 1) # remove previous anchor
              duration  = (finish.time - start.time).to_r
              is_slide  = Deresute::SuperNote === start
              is_long   = duration >= 2
              is_cut    = !is_slide && duration >= 16
              is_para   = (finish.pos <=> start.pos).zero?
              
              is_bent   = is_slide && is_long && !is_cut && !is_para
              coords.push *(note_convert.call(start) * (coords.empty? ? 1 : sharpness))  # Prepare start anchor
              if is_bent then
                pos = [start,finish].map(&:pos)
                midway_notes = chart_notes.select { |note| note.time > start.time && note.time < finish.time && note.pos == start.pos }
                is_early = !midway_notes.empty?
                midway_notes.clear
                
                if is_early
                  coords.push *(coord_convert.call(pos.first + (pos.last - pos.first) * 0.2, start.time.to_r + (BENT_RANGE - BENT_SIZE * 2)) * sharpness)
                  coords.push *coord_convert.call(pos.last, start.time.to_r + (BENT_RANGE - BENT_SIZE))
                  coords.push *(coord_convert.call(pos.last, start.time.to_r + BENT_RANGE) * sharpness)
                else
                  coords.push *(coord_convert.call(pos.first, finish.time.to_r - BENT_RANGE) * sharpness)
                  coords.push *coord_convert.call(pos.first, finish.time.to_r - (BENT_RANGE - BENT_SIZE))
                  coords.push *(coord_convert.call(pos.first + (pos.last - pos.first) * 0.2, finish.time.to_r - (BENT_RANGE - BENT_SIZE * 2)) * sharpness)
                end
                pos.clear
              end
              coords.push *(note_convert.call(finish) * sharpness) # Put temporary anchor (unless final)
              if !is_cut then
                path_set.bezier *coords
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
                    flip = note.dir == 1 ? true : false
                    flip = !flip if nth.odd?
                    4
                  when Deresute::SuperNote
                    3
                  end
          image = IMAGE_NOTES[type.pred]
          image = image.flop if flip
          basis_image.composite!(image, *note_convert.call(note).map { |c| c + MARGIN_IMAGE - 8 }, Magick::OverCompositeOp)
        end
        
        Magick::Image.new(final_width,final_height + BEAT_HEIGHT * 1) { self.background_color = 'white' }.tap do |final_image|
          0.step(measure_finish + split_size, split_size).each_with_index do |measure, column|
            if false
              y_off = ((column  * split_size - 0.5) * BEAT_HEIGHT).round
            else
              y_off = ((measure_finish - split_size * (column + 1) - 0.5) * BEAT_HEIGHT).round
            end
            sp_w  = MARGIN_LINESET * 2 + BEAT_WIDTH
            sp_h  = (split_size + 1) * BEAT_HEIGHT
            
            pix   = basis_image.dispatch(MARGIN_IMAGE, MARGIN_IMAGE + y_off, sp_w, sp_h,'RGBA')
            spl   = Magick::Image.constitute(sp_w, sp_h, 'RGBA', pix)
            final_image.composite!(spl, MARGIN_IMAGE + (column) * sp_w, MARGIN_IMAGE, Magick::OverCompositeOp)
            pix.clear
            spl.destroy!
          end
          
          dir     = File.join('chart.image')
          ctime   = Time.now
          fn      = File.join(dir,"%03d_%d.%s.%d.png")
          fmode   = []
          fmode  << [:NM,:MR][nth % 2]
          
          forepl  = Dir[File.join(dir,"%03d_%d.*.png" % [@song_id,@diff_id])]
          frepl   = Dir[File.join(dir,"%03d_%d.%s.*.png" % [@song_id,@diff_id,fmode*''])]
          if frepl.empty? && !forepl.empty? then
            # force renaming to old convention
            forepl.each do |f|
              fm = /^(.+)\/(\d{3})[_](\d)[.](\d+)[.]png$/.match(f)
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

