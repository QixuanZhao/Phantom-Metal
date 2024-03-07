//
//  spline.h
//  Phantom
//
//  Created by TSAR Weasley on 2023/12/7.
//

#ifndef spline_h
#define spline_h

#define MAX_ORDER 32
#define MAX_KNOTS (MAX_ORDER * 2)
#define MAX_FUNCTIONS (MAX_KNOTS - 1)

namespace spline {

class BSplineBasis {
private:
    constant float * knots;
    int knotCount;
    int degree;
public:
    BSplineBasis(constant float* knots, int count, int degree) : knots(knots), knotCount(count), degree(degree) { }
    
    /*
     * i for knot interval index
     * u for parameter
     */
    void calc(float u, int i, float4 result[MAX_ORDER]) const;
};

}

#endif /* spline_h */
