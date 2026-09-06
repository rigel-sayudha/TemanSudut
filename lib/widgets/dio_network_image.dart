import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

class DioNetworkImage extends StatefulWidget {
  final String url;
  final double? height;
  final double? width;
  final BoxFit fit;
  final Widget? loadingWidget;
  final Widget? errorWidget;

  const DioNetworkImage({
    super.key,
    required this.url,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
    this.loadingWidget,
    this.errorWidget,
  });

  @override
  State<DioNetworkImage> createState() => _DioNetworkImageState();
}

class _DioNetworkImageState extends State<DioNetworkImage> {
  Uint8List? _bytes;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _fetchImage();
  }

  Future<void> _fetchImage() async {
    try {
      final dio = Dio();
      final response = await dio.get<List<int>>(
        widget.url,
        options: Options(responseType: ResponseType.bytes),
      );
      if (mounted && response.statusCode == 200) {
        setState(() {
          _bytes = Uint8List.fromList(response.data!);
          _loading = false;
        });
      } else {
        if (mounted) {
          setState(() {
            _loading = false;
            _error = true;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return SizedBox(
        height: widget.height,
        width: widget.width,
        child:
            widget.loadingWidget ??
            Container(
              color: Colors.grey[200],
              child: const Center(child: CircularProgressIndicator()),
            ),
      );
    }
    if (_error || _bytes == null) {
      return SizedBox(
        height: widget.height,
        width: widget.width,
        child:
            widget.errorWidget ??
            Container(
              color: Colors.grey[200],
              child: const Center(
                child: Icon(Icons.broken_image, color: Colors.grey),
              ),
            ),
      );
    }
    return Image.memory(
      _bytes!,
      height: widget.height,
      width: widget.width,
      fit: widget.fit,
    );
  }
}
