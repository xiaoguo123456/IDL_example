pro week_five_study
  ; 本程序用于解决Modis Grid文件的重投影并输出为Geotiff格式
  
; 总体思路
; 1. 先获取Modis Grid产品的数据(这里包括获取全局属性StructMetadata.0、LST_Day_1km(陆地和海洋的温度_1km分辨率)数据集及其属性)
; 2. 对上面获取数据进行处理(全局属性提取左上点和右下点的经纬度坐标以及lst数据的行列数、lst数据集的计算(得到真实的lst数据))
; 3. 根据上面得到的两个点的经纬度坐标以及行列数获取x、y方向上的精确分辨率（一个像元的长宽代表的实际距离）
; 4. 有上面的数据可以计算每一个像元的经纬度坐标(像元的纬度和经度分别用一个数组存储, 转换的时候需要这两个数组)
; 5. 确定好投影参数然后得到投影之后的经纬度数组(均是一维)
; 6. 由经纬度数组进行一些系列的处理得到行列数组，最后根据行列数组将lst数据填充到现在的投影好了的坐标系统里
 
  ; 路径
  in_path = 'D:/IDL_program/experiment_data/chapter_3/modis_grid'
  out_path = 'D:/IDL_program/experiment_data/chapter_3/modis_grid/geo_out'
  ; 检测out_path是否存在，不存在那么创建(当然，你可以亲自去文件资源管理器看看并亲自创建，这里用代码实现仅仅是为了装逼，可惜我装成了._.)
  if file_test(out_path) eq 0 then begin
    file_mkdir, out_path
  endif
  
  ; 获取所有文件的路径以及文件数量
  file_path_array = file_search(in_path, '*.hdf', count=file_count)
  ; 传入目录(in_path)，指定 查找文件的的限制条件(*.hdf), 获取查找到的文件数量(file_count)
  
  ; 循环获取每个文件的数据以及进行相关处理
  for file_i = 0, file_count - 1 do begin
    ; 记录一下每一次循环开始的时间
    start = systime(1)
    
    ; 该循环下的文件的路径
    file_path = file_path_array[file_i]
    
    ; 获取文件的id
    file_id = hdf_sd_start(file_path, /read)
    
    ; 获取全局属性StructMetadata.0的index
    metadata_indedx = hdf_sd_attrfind(file_id, 'StructMetadata.0')
    ; 传入文件id，传入全局属性的名称(如果是获取数据集属性也是用这个函数，只是传入数据集的id，传入数据集的属性名称)
    
    ; 获取全局属性StructMetadata.0的数据
    hdf_sd_attrinfo, file_id, metadata_indedx, data=metadata  ; 这里data返回的是一个字符串
    ; 这里传入文件id，传入全局属性的index，data=返回该属性的数据，这里用变量metadata接收
    
    ; 接下来需要对全局属性的对我们有用的数据进行提取(这里只有左上点和右下点的经纬度坐标需要我们提取)
    ; 获取字符串'UpperLeftPointMtrs'的第一个字符的下标
    start_pos = strpos(metadata, 'UpperLeftPointMtrs')  ; 传入一个字符串格式的变量,再传入需要查找的字符串
    ; 获取字符串'UpperLeftPointMtrs'
    end_pos = strpos(metadata, 'LowerRightMtrs')
    ; 获取'UpperLeftPointMtrs'与'UpperLeftPointMtrs'中间的字符串
    ; 中间字符串的长度
    len = end_pos - start_pos
    ; 截取中间字符串
    str = strmid(metadata, start_pos, len)  ; 传入需要切片的字符串、传入开始切片的位置、传入切片的长度
    ; split字符串——》将得到的中间字符串以某个字符(或者多个字符)作为划分点，将字符串一分为二(当然，如果有多个字符即多个划分点那么就一分为多)
    ; (接上^)得到的多个子字符串以数组形式输出
    son_str_array = strsplit(str, '=(,)', /extract)  ; 传入需要划分的字符串，传入划分的字符(显然这里有=~(~)~,~四个字符作为划分点)
    ; 另外需要说明的是，如果不传入参数/extract，那么输出的每个子字符串的首字符在原字符串种的下标组成的数组，而不是每个子字符串组成的数组
    ; 获取左上点的经纬度坐标
    ul_prj_lon = double(son_str_array[1])
    ; 由于得到的son_str_array[1]是一个字符串形的经度，需要将其转化为浮点型，这里使用double()函数(精度比float()函数高)将其转化为浮点型，下面类似
    ul_prj_lat = double(son_str_array[2])
    
    ; 上面是提取左上角点的经纬度，现在类似的操作去提取右下角点的经纬度
    start_pos = strpos(metadata, 'LowerRightMtrs')
    end_pos = strpos(metadata, 'Projection')
    ; 对上面从索引为start_pos ————》 end_pos的字符串进行截取
    ; 需要截取的字符串的长度
    len = end_pos - start_pos
    str = strmid(metadata, start_pos, end_pos)  ; 传入需要处理的字符串，传入 截取字符串的第一个字符串的索引，传入 截取字符串的长度
    ; split字符串
    son_str_array = strsplit(str, '=(,)', /extract)  ; 这里操作类似，不在重复
    ; 获取右下角点的经纬度
    lr_prj_lon = double(son_str_array[1])
    lr_prj_lat = double(son_str_array[2])
    
    
    ; 获取lst(陆地海洋温度)数据集的数据
    ; 获取lst数据集的index
    lst_index = hdf_sd_nametoindex(file_id, 'LST_Day_1km')  ; 传入数据集所在文件的id，传入数据集的名称
    ; 获取数据集的id
    lst_id = hdf_sd_select(file_id, lst_index)  ; 传入数据集所在文件的id，传入数据集的index
    ; 获取数据集的数据
    hdf_sd_getdata, lst_id, lst_data  ; 传入数据集的id，传入变量lst_data用于接收返回的该数据集的数据
    
    ; 获取lst数据集的属性(其实这一步可以省去，因为我们可以通过hdf explorer去查看)——》_FillValue、scale_factor属性
    ; 获取属性的index
    fv_index = hdf_sd_attrfind(lst_id, '_FillValue')
    sf_index = hdf_sd_attrfind(lst_id, 'scale_factor')
    ; 获取属性的内容
    hdf_sd_attrinfo, lst_id, fv_index, data=fv_data  ; 传入属性所在数据集的id，传入属性的index，data=返回该属性的内容，这里用变量fv_data接收
    hdf_sd_attrinfo, lst_id, sf_index, data=sf_data
    
    ; 对lst数据集进行处理
    lst_data = (lst_data ne fv_data[0]) * lst_data * sf_data[0]  ; 虽然这里fv_data只有一个数字，但是它是一个数组，不加[]结果会出乎意料，不信你可以试一下,具体数组与数组、数组与数字...怎么计算自己找一个例子看就明白了，这里不再演示
    
    ; 现在我们已从文件中获取到了我们需要的所有数据，那么文件就需要关闭(习惯问题和态度问题和素养问题和专业问题...)
    hdf_sd_endaccess, lst_id
    hdf_sd_end, file_id
    
    ; 获取数据的分辨率(你可以理解为一个像元的长宽(一般长宽相等)代表的实际距离)
    ; 理论上我们知道了左上角点的经纬度，右下角点的经纬度，那么我们只需要知道数据的行列数即可求得分辨率
    ; 获取lst数据(是一个二维数组形式)的行列数
    lst_size = size(lst_data)  ; 这里size()函数返回5个数(好像一维不是，二维也不是，自己试试就知道了)
    ; 第一个数表示维度:lst_data是二维数组，维度是2
    ; 第二个数表示列数
    ; 第三个数表示行数
    ; 第四个数表示数组元素的类型:会返回一个数字，这个数字是某一种类型的代号,譬如1我就认为它代表int、2就代表float型之类
    ; 第五个数表示数组元素的总个数:即列数乘以行数
    ; 获取lst数据的行列数
    lst_column = lst_size[1]  ; lst_size是数组这个应该不需要提醒了
    lst_row = lst_size[2]
    ; 计算lst数据的分辨率
    prj_resolution_x = (lr_prj_lon - ul_prj_lon) / lst_column
    prj_resolution_y = (ul_prj_lat - lr_prj_lat) / lst_row
    
    ; 计算每一个像元的经纬度并存储
    prj_x = fltarr(lst_column, lst_row)  ; 用来存放每一个像元的经度信息的数组,元素均初始化为0
    prj_y = fltarr(lst_column, lst_row)  ; 用来存放每一个像元的纬度信息的数组,元素均初始化为0
    ; 循环得到每一个像元的经度
    for i=0, lst_column - 1 do begin
      prj_x[i, *] = prj_x[i, *] + ul_prj_lon + prj_resolution_x * i
    endfor
    ; 循环得到每一个像元的纬度
    for i=0, lst_row - 1 do begin
      prj_y[*, i] = prj_y[*, i] + ul_prj_lat - prj_resolution_y * i
    endfor
    
    ; 初始化投影参数(就是告诉envi，没重投影前，我的投影信息是什么)
    sin_prj=map_proj_init('sinusoidal',/gctp,sphere_radius=6371007.181,center_longitude=0.0,false_easting=0.0,false_northing=0.0)
    ; 将正弦投影坐标转化为经纬度坐标
    geo_loc = map_proj_inverse(prj_x, prj_y, map_structure=sin_prj)  ; 传入正弦投影的经纬度坐标以及投影的参数信息
    ; geo_loc是二维数组，第0列是所有的经度坐标，第1列是所有的纬度坐标
    geo_x = geo_loc[0, *]
    geo_y = geo_loc[1, *]
    ; 获取经纬度坐标的最大小值
    lon_min = min(geo_x)
    lon_max = max(geo_x)
    lat_min = min(geo_y)
    lat_max = max(geo_y)
    ; 由lst数据集名称我们知道这是一个1km分辨率的数据(约等于0.01°),那么为了重投影之后结果不会有太大偏差，这里我们设置前后分辨率不变,后来的分辨率也是0.01°
    geo_resolution = 0.01
    ; 重投影后的列数
    geo_column = ceil((lon_max - lon_min) / geo_resolution)  ; 向上取整(自己理解吧，有需要我再说，下面的floor也是)
    ; 重投影后的行数
    geo_row = ceil((lat_max - lat_min) / geo_resolution)
    ; 重投影之后的lst数据的数组初始化
    box_lst_data = fltarr(geo_column, geo_row)
    ; 将所有lst数据的初始化结果改为-9999.0，因为原始的lst数据的无效值就是0，这里初始化为-9999.0只是为了作出区分
    box_lst_data[*, *] = -9999.0  ; 注意不能box_lst_data = -9999.0
    ; 获取转化后每一个像元的行列数
    geo_column_array = floor((geo_x - lon_min) / geo_resolution)  ; 向下取整
    geo_row_array = floor((geo_y - lat_min) / geo_resolution)
    ; 将原来的lst数据放到现在的box_lst_data
    box_lst_data[geo_column_array, geo_row_array] = lst_data
    
    ; 异常值(即前面的-9999值)填充
    ; 用来装已经经过处理的lst的数组
    box_lst_data_out = fltarr(geo_column, geo_row)
    ; 进入for循环进行检测(由于异常值需要参考周围的八个点，所以为了方便，这里将最外边的行列排除在外不处理)
    for geo_column_i = 1, geo_column - 2 do begin
      for geo_row_i = 1, geo_row - 2 do begin
        ; 检测当前lst值是否为有效值
        if box_lst_data[geo_column_i, geo_row_i] eq -9999.0 then begin
          ; 以该点为中心创建九宫格窗口
          temp_windows = box_lst_data[geo_column_i-1:geo_column_i+1, geo_row_i-1:geo_row_i+1]
          temp_windows = (temp_windows gt 0) * temp_windows  ; 注意这里是gt而不是ge，因为0.0是_FillValue
          temp_windows_sum = total(temp_windows)  ; 使用total()函数求得数组元素的总和
          temp_windows_num = total(temp_windows gt 0)  ; 求得有效的元素的个数
          ; 是否使用周围的点的lst数据得有一个阈值——》周围的有效点有几个
          if temp_windows_num gt 3 then begin
            box_lst_data_out[geo_column_i, geo_row_i] = temp_windows_sum / temp_windows_num
          endif
        endif else begin
            box_lst_data_out[geo_column_i, geo_row_i] = box_lst_data[geo_column_i, geo_row_i]
        endelse
      endfor  
    endfor
    
    ; geoinfo信息填写
    geo_info={$
      MODELPIXELSCALETAG:[geo_resolution,geo_resolution,0.0],$
      MODELTIEPOINTTAG:[0.0,0.0,0.0,lon_min,lat_max,0.0],$
      GTMODELTYPEGEOKEY:2,$
      GTRASTERTYPEGEOKEY:1,$
      GEOGRAPHICTYPEGEOKEY:4326,$
      GEOGCITATIONGEOKEY:'GCS_WGS_1984',$
      GEOGANGULARUNITSGEOKEY:9102,$
      GEOGSEMIMAJORAXISGEOKEY:6378137.0,$
      GEOGINVFLATTENINGGEOKEY:298.25722}
      
    ; 输出
    write_tiff, out_path + '/' + file_basename(file_path, '.hdf') + '_georef.tiff', box_lst_data_out, /float, geotiff=geo_info
    
    stop = systime(1)  ; 一次循环结束
    print, file_basename(file_path, '.hdf') + ': ' + strcompress(string(stop - start)) + 's'
  endfor
end
