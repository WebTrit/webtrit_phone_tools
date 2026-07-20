class ArbMergeUtil {
  static Map<String, dynamic> mergeArb(Map<String, dynamic> local, Map<String, dynamic> downloaded) {
    return {...local, ...downloaded};
  }
}
